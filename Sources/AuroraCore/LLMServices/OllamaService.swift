//
//  OllamaService.swift
//
//
//  Created by Dan Murrell Jr on 9/3/24.
//

import Foundation

/**
 `OllamaService` implements the `LLMServiceProtocol` to interact with the Ollama models via its API.
 This service allows for customizable API base URLs, making it flexible for different environments.
 */
public class OllamaService: LLMServiceProtocol {

    public let name = "Ollama"
    public var apiKey: String? // Not used for Ollama but included to satisfy the protocol

    public let maxTokenLimit: Int
    private let baseURL: URL
    internal var urlSession: URLSession

    /**
     Initializes a new `OllamaService` instance.

     - Parameters:
        - baseURL: The base URL for the Ollama API (e.g., `http://localhost:11400`).
        - maxTokenLimit: The maximum number of tokens allowed in a request.
        - apiKey: An optional API key, though not typically required for local Ollama instances.
        - urlSession: The URLSession instance used for network requests (default is URLSession.shared).
     */
    public init(baseURL: URL, maxTokenLimit: Int = 4096, apiKey: String? = nil, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.maxTokenLimit = maxTokenLimit
        self.apiKey = apiKey
        self.urlSession = urlSession
    }

    /**
     Sends a request to the Ollama API asynchronously.

     This method constructs the appropriate URL and HTTP request, sends the request to the Ollama service,
     and then processes the response to return a summarized result.

     - Parameters:
        - request: The `LLMRequest` containing the prompt and additional parameters for generating text.
     - Returns: An `LLMResponse` containing the generated text from the Ollama API.
     - Throws: An error if the request fails or the response is invalid.
     */
    public func sendRequest(_ request: LLMRequest) async throws -> LLMResponse {
        let prompt = request.prompt

        // Create the full URL with the model path
        guard let model = request.model else {
            throw NSError(domain: "OllamaService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model name is required."])
        }
        let url = baseURL.appendingPathComponent("api/v1/models/\(model)/generate")

        // Prepare the request body
        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "max_tokens": request.maxTokens,
            "temperature": request.temperature
        ]

        // Convert the body to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])

        // Create the URL request
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Perform the network request
        let (data, response) = try await urlSession.data(for: urlRequest)

        // Validate the response
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "OllamaService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Ollama API."])
        }

        // Decode the response data
        let decodedResponse = try JSONDecoder().decode(LLMResponse.self, from: data)

        return decodedResponse
    }

    /**
     Sends a request to the Ollama API using a completion handler.

     This method is similar to the asynchronous version but allows for a completion handler to be used
     for handling the result or any errors that may occur during the request.

     - Parameters:
        - request: The `LLMRequest` containing the prompt and additional parameters for generating text.
        - completion: A closure that handles the result of the request, either a successful `LLMResponse` or an error.
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
