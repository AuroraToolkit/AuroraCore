//
//  OpenAIService.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/**
 `OpenAIService` implements the `LLMServiceProtocol` to interact with the OpenAI API.
 This service allows flexible configuration for different models and settings, and now provides
 enhanced error handling using `LLMServiceError`.
 */
public class OpenAIService: LLMServiceProtocol {

    /// The name of the service, required by the protocol.
    public let name = "OpenAI"

    /// The base url for the OpenAI API.
    public var baseURL: String

    /// The API key used for authenticating requests to the OpenAI API.
    public var apiKey: String?

    /// The maximum token limit that can be processed by this service.
    public let maxTokenLimit: Int

    /**
     Initializes a new `OpenAIService` instance with the given API key and token limit.

     - Parameters:
        - baseURL: The base URL for the OpenAI API. Defaults to "https://api.openai.com".
        - apiKey: The API key used for authenticating requests to the OpenAI API.
        - maxTokenLimit: The maximum number of tokens allowed in a request. Defaults to 4096.
     */
    public init(baseURL: String = "https://api.openai.com", apiKey: String?, maxTokenLimit: Int = 4096) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.maxTokenLimit = maxTokenLimit
    }

    /**
     Sends a request to the OpenAI API and retrieves the response asynchronously.

     - Parameters:
        - request: The `LLMRequest` containing the prompt and model configuration.
     - Returns: The `LLMResponseProtocol` containing the generated text or an error if the request fails.
     - Throws: `LLMServiceError` if the request encounters an issue (e.g., missing API key, invalid response, etc.).
     */
    public func sendRequest(_ request: LLMRequest) async throws -> LLMResponseProtocol {
        guard let apiKey = apiKey else {
            throw LLMServiceError.missingAPIKey
        }


        // Validate the URL
        guard var components = URLComponents(string: baseURL) else {
            throw LLMServiceError.invalidURL
        }

        if components.scheme == nil || components.host == nil {
            throw LLMServiceError.invalidURL
        }

        components.path = "/v1/chat/completions"

        guard let url = components.url else {
            throw LLMServiceError.invalidURL
        }
        
        let body: [String: Any] = [
            "model": request.model ?? "gpt-4",
            "messages": [["role": "user", "content": request.prompt]],
            "max_tokens": request.maxTokens,
            "temperature": request.temperature
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMServiceError.invalidResponse(statusCode: -1)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw LLMServiceError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        do {
            let decodedResponse = try JSONDecoder().decode(OpenAILLMResponse.self, from: data)
            return decodedResponse
        } catch {
            throw LLMServiceError.decodingError
        }
    }

    /**
     Sends a request to the OpenAI API using a completion handler.

     - Parameters:
        - request: The `LLMRequest` containing the prompt and model configuration.
        - completion: A closure that handles the result, returning a successful `LLMResponse` or an error.
     */
    public func sendRequest(_ request: LLMRequest, completion: @escaping (Result<LLMResponseProtocol, Error>) -> Void) {
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
