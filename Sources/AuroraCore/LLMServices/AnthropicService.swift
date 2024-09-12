//
//  AnthropicService.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/**
 `AnthropicService` implements the `LLMServiceProtocol` to interact with the Anthropic API.
 It allows for flexible configuration for different models and temperature settings.
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

    /**
     Sends a request to the Anthropic API and retrieves the response asynchronously.

     - Parameters:
        - request: The `LLMRequest` containing the prompt and model configuration.
     - Returns: The `LLMResponse` containing the generated text or an error if the request fails.
     - Throws: An error if the request to the Anthropic API fails.
     */
    public func sendRequest(_ request: LLMRequest) async throws -> LLMResponse {
        guard let apiKey = apiKey else {
            throw NSError(domain: "AnthropicService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API key is missing."])
        }

        // Prepare the message request body
        let body: [String: Any] = [
            "model": request.model ?? "claude-3-5",
            "messages": [
                ["role": "user", "content": request.prompt]
            ],
            "max_tokens": request.maxTokens,
            "temperature": request.temperature
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])

        var urlRequest = URLRequest(url: URL(string: "\(baseURL)/v1/messages")!)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")  // Required Anthropic version header

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "AnthropicService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Anthropic API."])
        }

        let decodedResponse = try JSONDecoder().decode(LLMResponse.self, from: data)
        return decodedResponse
    }

    /**
     Sends a request to the Anthropic API using a completion handler.

     - Parameters:
        - request: The `LLMRequest` containing the prompt and model configuration.
        - completion: A closure that handles the result, returning a successful `LLMResponse` or an error.
     */
    public func sendRequest(_ request: LLMRequest, completion: @escaping (Result<LLMResponse, Error>) -> Void) {
        Task {
            do {
                let response = try await sendRequest(request)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
