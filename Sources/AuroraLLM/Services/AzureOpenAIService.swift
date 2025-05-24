//
//  AzureOpenAIService.swift
//  AuroraLLM
//
//

import AuroraCore
import Foundation
import os.log

/**
 `AzureOpenAIService` implements `LLMServiceProtocol` to interact with Azure OpenAI deployments.
 You must provide the Azure endpoint (baseURL), deployment name, API version, and API key.
 */
public class AzureOpenAIService: LLMServiceProtocol {
    /// The vendor identifier for this service.
    public let vendor = "AzureOpenAI"

    /// The name of the service instance, customizable at initialization.
    public var name: String

    /// The maximum context window size (combined input and output tokens) supported by Azure OpenAI.
    public var contextWindowSize: Int

    /// The maximum number of tokens allowed for the output (completion) in a single request.
    public var maxOutputTokens: Int

    /// Policy for handling input tokens when they exceed the service's input token limits.
    public var inputTokenPolicy: TokenAdjustmentPolicy

    /// Policy for handling output tokens when they exceed the service's max output token limit.
    public var outputTokenPolicy: TokenAdjustmentPolicy

    /// An optional default system prompt to set the behavior or persona of the model.
    public var systemPrompt: String?

    /// The base Azure OpenAI endpoint (e.g. "https://<resource>.openai.azure.com").
    private let baseURL: String

    /// The deployment name of the Azure OpenAI model.
    private let deploymentName: String

    /// The Azure OpenAI REST API version to use (e.g. "2023-05-15").
    private let apiVersion: String

    /// Optional logger for recording information and errors.
    private let logger: CustomLogger?

    /// The URLSession instance used for HTTP requests.
    private let urlSession: URLSession

    /**
     Initializes a new `AzureOpenAIService` for interacting with Azure OpenAI deployments.

     - Parameters:
       - name: The name of the service instance (default is "AzureOpenAI").
       - baseURL: The Azure OpenAI endpoint URL (e.g., "https://<resource>.openai.azure.com").
       - deploymentName: The deployment name of the model within Azure OpenAI.
       - apiVersion: The API version to use (default is "2023-05-15").
       - apiKey: The API key used to authenticate with the Azure endpoint.
       - contextWindowSize: The total context window size (input + output tokens). Defaults to 8192.
       - maxOutputTokens: The maximum number of tokens allowed in the output. Defaults to 2048.
       - inputTokenPolicy: The policy for handling input tokens exceeding limits. Defaults to `.adjustToServiceLimits`.
       - outputTokenPolicy: The policy for handling output tokens exceeding limits. Defaults to `.adjustToServiceLimits`.
       - systemPrompt: An optional default system prompt to set the model persona. Defaults to `nil`.
       - urlSession: The `URLSession` instance for network requests. Defaults to `.shared`.
       - logger: An optional `CustomLogger` for logging. Defaults to `nil`.
     */
    public init(
        name: String = "AzureOpenAI",
        baseURL: String,
        deploymentName: String,
        apiVersion: String = "2023-05-15",
        apiKey: String?,
        contextWindowSize: Int = 8192,
        maxOutputTokens: Int = 2048,
        inputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits,
        outputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits,
        systemPrompt: String? = nil,
        urlSession: URLSession = .shared,
        logger: CustomLogger? = nil
    ) {
        self.name = name
        self.baseURL = baseURL
        self.deploymentName = deploymentName
        self.apiVersion = apiVersion
        self.contextWindowSize = contextWindowSize
        self.maxOutputTokens = maxOutputTokens
        self.inputTokenPolicy = inputTokenPolicy
        self.outputTokenPolicy = outputTokenPolicy
        self.systemPrompt = systemPrompt
        self.urlSession = urlSession
        self.logger = logger
        // store credentials
        if let key = apiKey {
            SecureStorage.saveAPIKey(key, for: name)
            SecureStorage.saveBaseURL(baseURL, for: name)
        }
    }

    // MARK: - Non-streaming Request
    /**
     Sends a non-streaming request to Azure OpenAI asynchronously.

     - Parameter request: The `LLMRequest` containing the messages and configuration for the LLM service.

     - Returns: An `LLMResponseProtocol` containing the generated text from the model.
     - Throws: `LLMServiceError` if the request fails due to missing API key, invalid URL, non-2xx HTTP response, or decoding errors.
     */
    public func sendRequest(_ request: LLMRequest) async throws -> LLMResponseProtocol {
        try validateStreamingConfig(request, expectStreaming: false)

        // Build the URL components for the request
        guard var components = URLComponents(string: baseURL) else {
            throw LLMServiceError.invalidURL
        }

        components.path = "/openai/deployments/\(deploymentName)/chat/completions"
        components.queryItems = [URLQueryItem(name: "api-version", value: apiVersion)]
        guard let url = components.url else {
            throw LLMServiceError.invalidURL
        }

        // Use helper function for consistent system prompt handling
        let messagesPayload = prepareOpenAIMessagesPayload(from: request, serviceSystemPrompt: systemPrompt)

        let body: [String: Any] = [
            "messages": messagesPayload,
            "max_tokens": request.maxTokens,
            "temperature": request.temperature,
            "top_p": request.options?.topP ?? 1.0,
            "frequency_penalty": request.options?.frequencyPenalty ?? 0.0,
            "presence_penalty": request.options?.presencePenalty ?? 0.0,
            "stop": request.options?.stopSequences ?? [],
            "stream": false
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        logger?.debug("AzureOpenAIService [sendRequest] Sending request with keys: \(body.keys)", category: "AzureOpenAIService")

        // Minimize the risk of API key exposure
        guard let apiKey = SecureStorage.getAPIKey(for: name) else {
            throw LLMServiceError.missingAPIKey
        }
        urlRequest.setValue(apiKey, forHTTPHeaderField: "api-key")

        // Non-streaming response handling
        let (data, response) = try await urlSession.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            throw LLMServiceError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        logger?.debug("AzureOpenAIService [sendRequest] Response received from Azure OpenAI.", category: "AzureOpenAIService")

        let decodedResponse = try JSONDecoder().decode(OpenAILLMResponse.self, from: data)
        let finalResponse = decodedResponse.changingVendor(to: vendor)
        return finalResponse
    }

    // MARK: - Streaming Request
    /**
     Sends a streaming request to Azure OpenAI asynchronously.

     - Parameters:
       - request: The `LLMRequest` containing the messages and configuration for the LLM service. Must have `stream = true`.
       - onPartialResponse: A closure invoked with partial response chunks as they arrive.

     - Returns: An `LLMResponseProtocol` containing the final concatenated text from the model.
     - Throws: `LLMServiceError` if the request fails due to missing API key, invalid URL, non-2xx HTTP response, or decoding errors.
     */
    public func sendStreamingRequest(_ request: LLMRequest, onPartialResponse: ((String) -> Void)?) async throws -> LLMResponseProtocol {
        try validateStreamingConfig(request, expectStreaming: true)

        // URL and request setup
        guard var components = URLComponents(string: baseURL) else {
            throw LLMServiceError.invalidURL
        }
        components.path = "/openai/deployments/\(deploymentName)/chat/completions"
        components.queryItems = [URLQueryItem(name: "api-version", value: apiVersion)]
        guard let url = components.url else {
            throw LLMServiceError.invalidURL
        }

        // Use helper function for consistent system prompt handling
        let messagesPayload = prepareOpenAIMessagesPayload(from: request, serviceSystemPrompt: systemPrompt)

        let body: [String: Any] = [
            "messages": messagesPayload,
            "max_tokens": request.maxTokens,
            "temperature": request.temperature,
            "top_p": request.options?.topP ?? 1.0,
            "frequency_penalty": request.options?.frequencyPenalty ?? 0.0,
            "presence_penalty": request.options?.presencePenalty ?? 0.0,
            "stop": request.options?.stopSequences ?? [],
            "stream": true
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        logger?.debug("AzureOpenAIService [sendStreamingRequest] Sending streaming request with keys: \(body.keys).", category: "AzureOpenAIService")

        // Minimize the risk of API key exposure
        guard let apiKey = SecureStorage.getAPIKey(for: name) else {
            throw LLMServiceError.missingAPIKey
        }
        urlRequest.setValue(apiKey, forHTTPHeaderField: "api-key")

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = StreamingDelegate(
                vendor: vendor,
                model: deploymentName,
                logger: logger,
                onPartialResponse: onPartialResponse ?? { _ in },
                continuation: continuation
            )
            logger?.debug("AzureOpenAIService [sendStreamingRequest] Starting streaming request", category: "AzureOpenAIService")
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            session.dataTask(with: urlRequest).resume()
        }
    }
    
    // MARK: - Streaming Delegate
    private class StreamingDelegate: NSObject, URLSessionDataDelegate {
        let vendor: String
        let model: String
        let logger: CustomLogger?
        let onPartialResponse: (String) -> Void
        let continuation: CheckedContinuation<LLMResponseProtocol, Error>
        var accumulated = ""

        init(vendor: String,
             model: String,
             logger: CustomLogger?,
             onPartialResponse: @escaping (String) -> Void,
             continuation: CheckedContinuation<LLMResponseProtocol, Error>)
        {
            self.vendor = vendor
            self.model = model
            self.logger = logger
            self.onPartialResponse = onPartialResponse
            self.continuation = continuation
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            guard let text = String(data: data, encoding: .utf8) else { return }
            logger?.debug("AzureOpenAIService.StreamingDelegate chunk received", category: "AzureOpenAIService")
            for line in text.split(separator: "\n") {
                if line == "data: [DONE]" {
                    let usage = OpenAILLMResponse.Usage(promptTokens: 0, completionTokens: 0, totalTokens: 0)
                    let final = OpenAILLMResponse(
                        choices: [OpenAILLMResponse.Choice(
                            delta: nil,
                            message: OpenAILLMResponse.Choice.Message(role: "assistant", content: accumulated),
                            finishReason: "stop"
                        )],
                        usage: usage,
                        vendor: vendor,
                        model: model
                    )
                    continuation.resume(returning: final)
                    return
                }
                if line.starts(with: "data:") {
                    let jsonPart = line.replacingOccurrences(of: "data: ", with: "")
                    if let jsonData = jsonPart.data(using: .utf8) {
                        do {
                            let partial = try JSONDecoder().decode(OpenAILLMResponse.self, from: jsonData)
                            if let delta = partial.choices.first?.delta?.content {
                                accumulated += delta
                                onPartialResponse(delta)
                            }
                        } catch {
                            logger?.error("AzureOpenAIService.StreamingDelegate decode error: \(error)", category: "AzureOpenAIService")
                        }
                    }
                }
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                continuation.resume(throwing: error)
            }
        }
    }
}
