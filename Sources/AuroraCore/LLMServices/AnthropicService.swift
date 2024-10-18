//
//  AnthropicService.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/**
 `AnthropicService` implements the `LLMServiceProtocol` to interact with the Anthropic API.
 It allows for flexible configuration for different models and temperature settings, and now provides
 detailed error handling using `LLMServiceError`.
 */
public class AnthropicService: LLMServiceProtocol {

    /// The name of the service, required by the protocol.
    public let name = "Anthropic"

    /// The base URL for the Anthropic API.
    private let baseURL: String

    /// The API key used for authenticating requests to the Anthropic API.
    public var apiKey: String?

    /// The maximum token limit that can be processed by this service.
    public let maxTokenLimit: Int

    /**
     Initializes a new `AnthropicService` instance with the given API key and token limit.

     - Parameters:
        - baseURL: The base URL for the Anthropic API. Defaults to "https://api.anthropic.com".
        - apiKey: The API key used for authenticating requests to the Anthropic API.
        - maxTokenLimit: The maximum number of tokens allowed in a request. Defaults to 4096.
     */
    public init(baseURL: String = "https://api.anthropic.com", apiKey: String?, maxTokenLimit: Int = 4096) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.maxTokenLimit = maxTokenLimit
    }

    actor StreamingState {
        var accumulatedContent = ""
        var inputTokens = 0
        var outputTokens = 0

        func appendContent(_ content: String) {
            accumulatedContent += content
        }

        func updateTokenUsage(input: Int, output: Int) {
            inputTokens += input
            outputTokens += output
        }

        func getUsage() -> AnthropicLLMResponse.Usage {
            return AnthropicLLMResponse.Usage(input_tokens: inputTokens, output_tokens: outputTokens)
        }
    }

    /**
     Sends a request to the Anthropic API and retrieves the response asynchronously.

     - Parameters:
        - request: The `LLMRequest` containing the messages and model configuration.
        - Returns: The `LLMResponseProtocol` containing the generated text or an error if the request fails.
     - Throws: `LLMServiceError` if the request encounters an issue (e.g., missing API key, invalid response, etc.).
     */
    public func sendRequest(_ request: LLMRequest, onPartialResponse: ((String) -> Void)? = nil) async throws -> LLMResponseProtocol {
        // Check if streaming is enabled. If not, redirect to the non-streaming version.
        guard request.stream else {
            return try await sendRequest(request)
        }

        guard let apiKey = apiKey else {
            throw LLMServiceError.missingAPIKey
        }

        // Map LLMMessage instances to the format expected by the API
        var systemMessage: String? = nil
        let userMessages = request.messages.compactMap { message -> [String: String]? in
            if message.role == .system {
                systemMessage = message.content
                return nil
            } else {
                return ["role": message.role.rawValue, "content": message.content]
            }
        }

        // Construct the body with a top-level system parameter
        var body: [String: Any] = [
            "model": request.model ?? "claude-3-5-sonnet-20240620",
            "messages": userMessages,
            "temperature": request.temperature,
            "max_tokens": request.maxTokens,
            "stream": request.stream
        ]

        // Add the system message if available
        if let systemMessage = systemMessage {
            body["system"] = systemMessage
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])

        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            throw LLMServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")  // Required Anthropic version header

        let state = StreamingState()

        // Handle streaming
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                Task {
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let data = data else {
                        continuation.resume(throwing: LLMServiceError.invalidResponse(statusCode: -1))
                        return
                    }

                    // Process the streaming data asynchronously
                    if let partialContent = String(data: data, encoding: .utf8) {
                        await state.appendContent(partialContent)
                        onPartialResponse?(partialContent)
                    }

                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        let usage = await state.getUsage()
                        let finalResponse = AnthropicLLMResponse(
                            id: UUID().uuidString,  // Placeholder for actual ID from API if available
                            type: "response",
                            role: "assistant",
                            content: [AnthropicLLMResponse.Content(type: "text", text: await state.accumulatedContent)],
                            stopReason: nil,  // Assuming we don't have this in streaming
                            usage: usage
                        )
                        continuation.resume(returning: finalResponse)
                    } else {
                        continuation.resume(throwing: LLMServiceError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1))
                    }
                }
            }
            task.resume()
        }
    }

    // Non-streaming method
    public func sendRequest(_ request: LLMRequest) async throws -> LLMResponseProtocol {
        guard let apiKey = apiKey else {
            throw LLMServiceError.missingAPIKey
        }

        // Map LLMMessage instances to the format expected by the API
        var systemMessage: String? = nil
        let userMessages = request.messages.compactMap { message -> [String: String]? in
            if message.role == .system {
                systemMessage = message.content
                return nil
            } else {
                return ["role": message.role.rawValue, "content": message.content]
            }
        }

        // Construct the body with a top-level system parameter
        var body: [String: Any] = [
            "model": request.model ?? "claude-3-5-sonnet-20240620",
            "messages": userMessages,
            "temperature": request.temperature,
            "max_tokens": request.maxTokens
        ]

        if let systemMessage = systemMessage {
            body["system"] = systemMessage
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])

        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            throw LLMServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")  // Required Anthropic version header

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw LLMServiceError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let decodedResponse = try JSONDecoder().decode(AnthropicLLMResponse.self, from: data)
        return decodedResponse
    }
}
