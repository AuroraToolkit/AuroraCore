//
//  OllamaService.swift
//
//
//  Created by Dan Murrell Jr on 9/3/24.
//

import Foundation
import os.log
import AuroraCore

/**
 `OllamaService` implements the `LLMServiceProtocol` to interact with the Ollama models via its API.
 This service supports customizable API base URLs and allows interaction with models using both streaming and non-streaming modes.
 */
public class OllamaService: LLMServiceProtocol {

    /// A logger for recording information and errors within the `AnthropicService`.
    private let logger: CustomLogger?

    /// The name of the service vendor, required by the protocol.
    public var vendor: String

    /// The name of the service instance, which can be customized during initialization
    public var name: String

    // `OllamaService` is not a local LLM service.
    public let isLocal: Bool = false

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
    internal var urlSession: URLSession

    /**
     Initializes a new `OllamaService` instance.

     - Parameters:
        - vendor: The name of the service vendor (default is `"Ollama"`).
        - name: The name of the service instance (default is `"Ollama"`).
        - baseURL: The base URL for the Ollama API (default is `"http://localhost:11434"`).
        - apiKey: An optional API key, though not required for local Ollama instances.
        - contextWindowSize: The size of the context window used by the service. Defaults to 4096.
        - maxOutputTokens: The maximum number of tokens allowed for output in a single request. Defaults to 4096.
        - inputTokenPolicy: The policy to handle input tokens exceeding the service's limit. Defaults to `.adjustToServiceLimits`.
        - outputTokenPolicy: The policy to handle output tokens exceeding the service's limit. Defaults to `.adjustToServiceLimits`.
        - systemPrompt: The default system prompt for this service, used to set the behavior or persona of the model.
        - urlSession: The `URLSession` instance used for network requests. Defaults to a `.default` configuration.
        - logger: An optional logger for recording information and errors. Defaults to `nil`.
     */
    public init(vendor: String = "Ollama", name: String = "Ollama", baseURL: String = "http://localhost:11434", contextWindowSize: Int = 4096, maxOutputTokens: Int = 4096, inputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits, outputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits, systemPrompt: String? = nil, urlSession: URLSession = URLSession(configuration: .default), logger: CustomLogger? = nil) {
        self.vendor = vendor
        self.name = name
        self.baseURL = baseURL
        self.contextWindowSize = contextWindowSize
        self.maxOutputTokens = maxOutputTokens
        self.inputTokenPolicy = inputTokenPolicy
        self.outputTokenPolicy = outputTokenPolicy
        self.systemPrompt = systemPrompt
        self.urlSession = urlSession
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
        // Ensure streaming is disabled for this method
        guard request.stream == false else {
            throw LLMServiceError.custom(message: "Streaming is not supported in sendRequest(). Use sendStreamingRequest() instead.")
        }

        // Validate the base URL
        guard var components = URLComponents(string: baseURL) else {
            throw LLMServiceError.invalidURL
        }

        components.path = "/api/generate"
        guard let url = components.url else {
            throw LLMServiceError.invalidURL
        }

        // Combine all messages into a single prompt text, following Ollama’s expected format
        let prompt = request.messages.map { "\($0.role.rawValue.capitalized): \($0.content)" }.joined(separator: "\n")

        // Construct the request body as per Ollama API, utilizing options for configurable parameters
        let body: [String: Any] = [
            "model": request.model ?? "llama3.2",  // Default to llama3.2
            "prompt": prompt,
            "max_tokens": request.maxTokens,
            "temperature": request.temperature,
            "top_p": request.options?.topP ?? 1.0,
            "frequency_penalty": request.options?.frequencyPenalty ?? 0.0,
            "presence_penalty": request.options?.presencePenalty ?? 0.0,
            "stop": request.options?.stopSequences ?? [],
            "stream": false
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

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
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
    public func sendStreamingRequest(_ request: LLMRequest, onPartialResponse: ((String) -> Void)? = nil) async throws -> LLMResponseProtocol {
        // Ensure streaming is enabled for this method
        guard request.stream else {
            throw LLMServiceError.custom(message: "Streaming is required in sendStreamingRequest(). Set request.stream to true.")
        }

        // Validate the base URL
        guard var components = URLComponents(string: baseURL) else {
            throw LLMServiceError.invalidURL
        }

        components.path = "/api/generate"
        guard let url = components.url else {
            throw LLMServiceError.invalidURL
        }

        // Combine all messages into a single prompt text, following Ollama’s expected format
        let prompt = request.messages.map { "\($0.role.rawValue.capitalized): \($0.content)" }.joined(separator: "\n")

        // Construct the request body as per Ollama API
        let body: [String: Any] = [
            "model": request.model ?? "llama3.2",  // Default to llama3.2
            "prompt": prompt,
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

        logger?.debug("OllamaService [sendRequest] Sending streaming request with keys: \(body.keys).", category: "OllamaService")

        return try await withCheckedThrowingContinuation { continuation in
            let streamingDelegate = StreamingDelegate(
                vendor: vendor,
                model: request.model ?? "llama3.2",
                logger: logger,
                onPartialResponse: onPartialResponse ?? { _ in },
                continuation: continuation
            )
            let session = URLSession(configuration: .default, delegate: streamingDelegate, delegateQueue: nil)
            let task = session.dataTask(with: urlRequest)
            task.resume()
        }
    }

    internal class StreamingDelegate: NSObject, URLSessionDataDelegate {
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
             continuation: CheckedContinuation<LLMResponseProtocol, Error>) {
            self.vendor = vendor
            self.model = model
            self.logger = logger
            self.onPartialResponse = onPartialResponse
            self.continuation = continuation
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
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
                        created_at: partialResponse.created_at,
                        response: accumulatedContent,
                        done: true,
                        eval_count: partialResponse.eval_count
                    )
                    continuation.resume(returning: finalResponse)
                    return
                }
            } catch {
                logger?.error("Decoding error: \(error.localizedDescription)", category: "OllamaService.StreamingDelegate")
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                continuation.resume(throwing: error)
            }
        }
    }
}
