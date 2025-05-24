//
//  OllamaService.swift
//
//
//  Created by Dan Murrell Jr on 9/3/24.
//

import AuroraCore
import Foundation
import os.log

/**
 `OllamaService` implements the `LLMServiceProtocol` to interact with the Ollama models via its API.
 This service supports customizable API base URLs and allows interaction with models using both streaming and non-streaming modes.
 
 ## Timeout Configuration
 
 Local LLM models can vary significantly in loading and inference time depending on their size:
 - **Small models (0.6B-2B parameters)**: Typically respond within 30 seconds
 - **Medium models (7B-8B parameters)**: May take 60-120 seconds on first request
 - **Large models (13B+ parameters)**: Can require 2-5 minutes for initial loading
 
 By default, `OllamaService` uses extended timeouts (5 minutes for requests, 15 minutes total) to accommodate
 large model loading times. For faster models or if you prefer quicker failure detection, you can provide
 a custom `URLSession` with shorter timeouts.
 
 ### Example: Custom Timeout Configuration
 ```swift
 // For faster models - use shorter timeouts
 let fastConfig = URLSessionConfiguration.default
 fastConfig.timeoutIntervalForRequest = 60    // 1 minute
 fastConfig.timeoutIntervalForResource = 300  // 5 minutes
 let fastSession = URLSession(configuration: fastConfig)
 
 let ollamaService = OllamaService(
     name: "FastOllama",
     urlSession: fastSession
 )
 
 // For very large models - use even longer timeouts
 let slowConfig = URLSessionConfiguration.default
 slowConfig.timeoutIntervalForRequest = 600   // 10 minutes
 slowConfig.timeoutIntervalForResource = 1800 // 30 minutes
 let slowSession = URLSession(configuration: slowConfig)
 
 let largeModelService = OllamaService(
     name: "LargeModelOllama", 
     urlSession: slowSession
 )
 ```
 
 ## Model Performance Tips
 
 - **Pre-warm large models** by running them manually first: `ollama run qwen3:14b "hello"`
 - **Monitor system resources** when using models larger than your available RAM
 - **Use smaller models** for development and testing to reduce wait times
 */
public class OllamaService: LLMServiceProtocol {
    /// A logger for recording information and errors within the `AnthropicService`.
    private let logger: CustomLogger?

    /// The name of the service vendor, required by the protocol.
    public var vendor: String

    /// The name of the service instance, which can be customized during initialization
    public var name: String

    /// The base URL for the Ollama API (e.g., `http://localhost:11434`).
    public var baseURL: String

    /// The maximum context window size (total tokens, input + output) supported by the service, defaults to 4k.
    public var contextWindowSize: Int

    /// The maximum number of tokens allowed for output (completion) in a single request, defaults to 4k.
    public var maxOutputTokens: Int

    /// Specifies the policy to handle input tokens when they exceed the service's input token limit, defaults to `.adjustToServiceLimits`.
    public var inputTokenPolicy: TokenAdjustmentPolicy

    /// Specifies the policy to handle output tokens when they exceed the service's max output token limit, defaults to `adjustToServiceLimits`.
    public var outputTokenPolicy: TokenAdjustmentPolicy

    /// The default system prompt for this service, used to set the behavior or persona of the model.
    public var systemPrompt: String?

    /// The URL session used to send basic requests.
    var urlSession: URLSession

    // The URL session configuration used for network requests.
    private let sessionConfiguration: URLSessionConfiguration

    // The default model for both sendRequest* methods, defaults to `gemma3`.
    private let defaultModel = "gemma3"

    /**
     Initializes a new `OllamaService` instance.

     - Parameters:
        - vendor: The name of the service vendor (default is `"Ollama"`).
        - name: The name of the service instance (default is `"Ollama"`).
        - baseURL: The base URL for the Ollama API (default is `"http://localhost:11434"`).
        - contextWindowSize: The size of the context window used by the service. Defaults to 4096.
        - maxOutputTokens: The maximum number of tokens allowed for output in a single request. Defaults to 4096.
        - inputTokenPolicy: The policy to handle input tokens exceeding the service's limit. Defaults to `.adjustToServiceLimits`.
        - outputTokenPolicy: The policy to handle output tokens exceeding the service's limit. Defaults to `.adjustToServiceLimits`.
        - systemPrompt: The default system prompt for this service, used to set the behavior or persona of the model.
        - urlSession: The `URLSession` instance used for network requests. If `nil`, creates a session with extended timeouts (5 min request, 15 min total) suitable for large model loading. For faster models or custom timeout requirements, provide your own configured session.
        - logger: An optional logger for recording information and errors. Defaults to `nil`.
        
     - Note: The default timeout configuration is optimized for large models that may take several minutes to load initially. If you're using smaller, faster models or prefer quicker failure detection, consider providing a custom `URLSession` with shorter timeouts.
     */
    public init(
        vendor: String = "Ollama",
        name: String = "Ollama",
        baseURL: String = "http://localhost:11434",
        contextWindowSize: Int = 4096,
        maxOutputTokens: Int = 4096,
        inputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits,
        outputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits,
        systemPrompt: String? = nil,
        urlSession: URLSession? = nil,
        logger: CustomLogger? = nil
    ) {
        self.vendor = vendor
        self.name = name
        self.baseURL = baseURL
        self.contextWindowSize = contextWindowSize
        self.maxOutputTokens = maxOutputTokens
        self.inputTokenPolicy = inputTokenPolicy
        self.outputTokenPolicy = outputTokenPolicy
        self.systemPrompt = systemPrompt

        // Create configuration optimized for local LLM model loading times
        if let urlSession = urlSession {
            self.sessionConfiguration = urlSession.configuration
            self.urlSession = urlSession
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 300   // 5 minutes - allows for large model loading
            config.timeoutIntervalForResource = 900  // 15 minutes - total time for complex operations
            self.sessionConfiguration = config
            self.urlSession = URLSession(configuration: config)
        }

        self.logger = logger
    }

    // MARK: - Actor for Streaming State

    actor StreamingState {
        var accumulatedContent = ""

        // Helper methods to mutate the actor's state
        func appendContent(_ content: String) {
            accumulatedContent += content
        }

        func getFinalContent() -> String {
            return accumulatedContent
        }
    }

    // MARK: - Non-streaming Request

    /**
     Sends a non-streaming request to the Ollama API and retrieves the response asynchronously.

     - Parameter request: The `LLMRequest` containing the messages and model configuration.

     - Returns: The `LLMResponseProtocol` containing the generated text or an error if the request fails.
     - Throws: `LLMServiceError` if the request encounters an issue (e.g., invalid response, decoding error, etc.).
     */
    public func sendRequest(_ request: LLMRequest) async throws -> LLMResponseProtocol {
        try validateStreamingConfig(request, expectStreaming: false)

        // Validate the base URL
        guard var components = URLComponents(string: baseURL) else {
            throw LLMServiceError.invalidURL
        }

        components.path = "/api/generate"
        guard let url = components.url else {
            throw LLMServiceError.invalidURL
        }

        // Use helper function and combine all messages into a single prompt
        let messages = prepareMessages(from: request, serviceSystemPrompt: systemPrompt)
        let prompt = messages.map { "\($0.role.rawValue.capitalized): \($0.content)" }.joined(separator: "\n")

        // Construct the request body as per Ollama API
        let body: [String: Any] = [
            "model": request.model ?? defaultModel,
            "prompt": prompt,
            "max_tokens": request.maxTokens,
            "temperature": request.temperature,
            "top_p": request.options?.topP ?? 1.0,
            "frequency_penalty": request.options?.frequencyPenalty ?? 0.0,
            "presence_penalty": request.options?.presencePenalty ?? 0.0,
            "stop": request.options?.stopSequences ?? [],
            "stream": false,
        ]

        // Serialize the request body into JSON
        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])

        // Configure the URLRequest
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        logger?.debug("OllamaService [sendRequest] Sending request with keys: \(body.keys)", category: "OllamaService")

        // Non-streaming response handling
        let (data, response) = try await urlSession.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            throw LLMServiceError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        logger?.debug("OllamaService [sendRequest] Response received from Ollama.", category: "OllamaService")

        // Attempt to decode the response from the Ollama API
        do {
            let decodedResponse = try JSONDecoder().decode(OllamaLLMResponse.self, from: data)
            let finalResponse = decodedResponse.changingVendor(to: vendor)
            return finalResponse
        } catch {
            throw LLMServiceError.decodingError
        }
    }

    // MARK: - Streaming Request

    /**
     Sends a streaming request to the Ollama API and retrieves partial responses asynchronously.

     - Parameters:
        - request: The `LLMRequest` containing the messages and model configuration.
        - onPartialResponse: A closure to handle partial responses during streaming.

     - Returns: The `LLMResponseProtocol` containing the final text or an error if the request fails.
     - Throws: `LLMServiceError` if the request encounters an issue (e.g., invalid response, decoding error, etc.).
     */
    public func sendStreamingRequest(_ request: LLMRequest, onPartialResponse: ((String) -> Void)?) async throws -> LLMResponseProtocol {
        try validateStreamingConfig(request, expectStreaming: true)

        // Validate the base URL
        guard var components = URLComponents(string: baseURL) else {
            throw LLMServiceError.invalidURL
        }

        components.path = "/api/generate"
        guard let url = components.url else {
            throw LLMServiceError.invalidURL
        }

        // Use helper function and combine all messages into a single prompt
        let messages = prepareMessages(from: request, serviceSystemPrompt: systemPrompt)
        let prompt = messages.map { "\($0.role.rawValue.capitalized): \($0.content)" }.joined(separator: "\n")

        // Construct the request body as per Ollama API
        let body: [String: Any] = [
            "model": request.model ?? defaultModel, 
            "prompt": prompt,
            "max_tokens": request.maxTokens,
            "temperature": request.temperature,
            "top_p": request.options?.topP ?? 1.0,
            "frequency_penalty": request.options?.frequencyPenalty ?? 0.0,
            "presence_penalty": request.options?.presencePenalty ?? 0.0,
            "stop": request.options?.stopSequences ?? [],
            "stream": true,
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        logger?.debug("OllamaService [sendRequest] Sending streaming request with keys: \(body.keys).", category: "OllamaService")

        return try await withCheckedThrowingContinuation { continuation in
            let streamingDelegate = StreamingDelegate(
                vendor: vendor,
                model: request.model ?? defaultModel,
                logger: logger,
                onPartialResponse: onPartialResponse ?? { _ in },
                continuation: continuation
            )
            let session = URLSession(configuration: self.sessionConfiguration, delegate: streamingDelegate, delegateQueue: nil)
            let task = session.dataTask(with: urlRequest)
            task.resume()
        }
    }

    class StreamingDelegate: NSObject, URLSessionDataDelegate {
        private let vendor: String
        private let model: String
        private let onPartialResponse: (String) -> Void
        private let continuation: CheckedContinuation<LLMResponseProtocol, Error>
        private let logger: CustomLogger?
        private var accumulatedContent = ""
        private var finalResponse: LLMResponseProtocol?

        init(vendor: String,
             model: String,
             logger: CustomLogger? = nil,
             onPartialResponse: @escaping (String) -> Void,
             continuation: CheckedContinuation<LLMResponseProtocol, Error>)
        {
            self.vendor = vendor
            self.model = model
            self.logger = logger
            self.onPartialResponse = onPartialResponse
            self.continuation = continuation
        }

        func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
            logger?.debug("Streaming response received. Processing...", category: "OllamaService.StreamingDelegate")

            do {
                let partialResponse = try JSONDecoder().decode(OllamaLLMResponse.self, from: data)
                let partialContent = partialResponse.response
                accumulatedContent += partialContent
                onPartialResponse(partialContent)

                if partialResponse.done {
                    // Finalize the response
                    let finalResponse = OllamaLLMResponse(
                        vendor: vendor,
                        model: model,
                        createdAt: partialResponse.createdAt,
                        response: accumulatedContent,
                        done: true,
                        evalCount: partialResponse.evalCount
                    )
                    continuation.resume(returning: finalResponse)
                    return
                }
            } catch {
                logger?.error("Decoding error: \(error.localizedDescription)", category: "OllamaService.StreamingDelegate")
            }
        }

        func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                continuation.resume(throwing: error)
            }
        }
    }
}
