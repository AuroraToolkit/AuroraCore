//
//  OllamaService.swift
//
//
//  Created by Dan Murrell Jr on 9/3/24.
//

import Foundation
import os.log

/**
 `OllamaService` implements the `LLMServiceProtocol` to interact with the Ollama models via its API.
 This service supports customizable API base URLs and allows interaction with models using both streaming and non-streaming modes.
 */
public class OllamaService: LLMServiceProtocol {

    /// A logger for recording information and errors within the `AnthropicService`.
    private let logger = Logger(subsystem: "com.mutantsoup.AuroraCore", category: "OllamaService")

    /// The name of the service vendor, required by the protocol.
    public let vendor = "Ollama"

    /// The name of the service instance, which can be customized during initialization
    public var name: String

    public var apiKey: String? // Not required for Ollama but included to satisfy the protocol

    /// Ollama does not require an API key for authentication.
    public let requiresAPIKey = false

    /// The maximum token limit that can be processed by this service.
    public let maxTokenLimit: Int

    /// The base URL for the Ollama API (e.g., `http://localhost:11434`).
    private let baseURL: String

    /// The URL session used to send requests.
    internal var urlSession: URLSession

    /**
     Initializes a new `OllamaService` instance.

     - Parameters:
        - name: The name of the service instance (default is `"Ollama"`).
        - baseURL: The base URL for the Ollama API (default is `"http://localhost:11434"`).
        - maxTokenLimit: The maximum number of tokens allowed in a request (default is 4096).
        - apiKey: An optional API key, though not required for local Ollama instances.
        - urlSession: The `URLSession` instance used for network requests (default is `URLSession.shared`).
     */
    public init(name: String = "Ollama", baseURL: String = "http://localhost:11434", maxTokenLimit: Int = 4096, apiKey: String? = nil, urlSession: URLSession = .shared) {
        self.name = name
        self.baseURL = baseURL
        self.maxTokenLimit = maxTokenLimit
        self.apiKey = apiKey
        self.urlSession = urlSession
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

     - Parameters:
        - request: The `LLMRequest` containing the messages and model configuration.
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

        logger.log("OllamaService \(#function) Sending request: \(body)")

        // Execute the request
        let (data, response) = try await urlSession.data(for: urlRequest)

        // Ensure the response is a valid HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMServiceError.invalidResponse(statusCode: -1)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw LLMServiceError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        if let jsonString = String(data: data, encoding: .utf8) {
            logger.log("OllamaService \(#function) Received response: \(jsonString)")
        }

        // Attempt to decode the response from the Ollama API
        do {
            let decodedResponse = try JSONDecoder().decode(OllamaLLMResponse.self, from: data)
            return decodedResponse
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

        logger.log("OllamaService \(#function) Sending request: \(body)")

        // Serialize the request body into JSON
        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])

        // Configure the URLRequest
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Initialize the streaming state
        let state = StreamingState()

        // Streaming handling
        return try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.dataTask(with: urlRequest) { [weak self] data, response, error in
                guard let self = self else { return }
                Task {
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let data = data else {
                        continuation.resume(throwing: LLMServiceError.invalidResponse(statusCode: -1))
                        return
                    }

                    if let jsonString = String(data: data, encoding: .utf8) {
                        self.logger.log("OllamaService \(#function) Received response: \(jsonString)")
                    }

                    // Process the data asynchronously using the actor to update state
                    if let partialContent = String(data: data, encoding: .utf8) {
                        await state.appendContent(partialContent)
                        onPartialResponse?(partialContent)
                    }

                    // Handle final response
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        let finalResponse = OllamaLLMResponse(response: await state.getFinalContent(), model: request.model)
                        continuation.resume(returning: finalResponse)
                    } else {
                        continuation.resume(throwing: LLMServiceError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1))
                    }
                }
            }
            task.resume()
        }
    }
}
