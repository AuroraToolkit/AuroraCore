//
//  OllamaService.swift
//
//
//  Created by Dan Murrell Jr on 9/3/24.
//

import Foundation

/**
 `OllamaService` implements the `LLMServiceProtocol` to interact with the Ollama models via its API.
 This service supports customizable API base URLs and allows interaction with models using both streaming and non-streaming modes.
 */
public class OllamaService: LLMServiceProtocol {

    /// The name of the service, required by the protocol.
    public let name = "Ollama"

    public var apiKey: String? // Not required for Ollama but included to satisfy the protocol

    /// The maximum token limit that can be processed by this service.
    public let maxTokenLimit: Int

    /// The base URL for the Ollama API (e.g., `http://localhost:11434`).
    private let baseURL: String

    /// The URL session used to send requests.
    internal var urlSession: URLSession

    /**
     Initializes a new `OllamaService` instance.

     - Parameters:
        - baseURL: The base URL for the Ollama API (default is `"http://localhost:11434"`).
        - maxTokenLimit: The maximum number of tokens allowed in a request (default is 4096).
        - apiKey: An optional API key, though not required for local Ollama instances.
        - urlSession: The `URLSession` instance used for network requests (default is `URLSession.shared`).
     */
    public init(baseURL: String = "http://localhost:11434", maxTokenLimit: Int = 4096, apiKey: String? = nil, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.maxTokenLimit = maxTokenLimit
        self.apiKey = apiKey
        self.urlSession = urlSession
    }

    /**
     Sends a request to the Ollama API and retrieves the response asynchronously.

     - Parameters:
        - request: The `LLMRequest` containing the messages and model configuration.
     - Returns: The `LLMResponseProtocol` containing the generated text or an error if the request fails.
     - Throws: `LLMServiceError` if the request encounters an issue (e.g., invalid response, decoding error, etc.).
     */
    public func sendRequest(_ request: LLMRequest) async throws -> LLMResponseProtocol {

        // Validate the base URL
        guard var components = URLComponents(string: baseURL) else {
            throw LLMServiceError.invalidURL
        }

        // Ensure the URL is valid
        if components.scheme == nil || components.host == nil {
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
            "model": request.model ?? "llama3.1",  // Default to llama3.1
            "prompt": prompt,
            "temperature": request.temperature,
            "max_tokens": request.maxTokens,
            "top_p": request.topP,
            "frequency_penalty": request.frequencyPenalty,
            "presence_penalty": request.presencePenalty,
            "stop": request.stopSequences ?? [],
            "stream": false  // Disable streaming for now
        ]

        // Serialize the request body into JSON
        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])

        // Configure the URLRequest
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Execute the request
        let (data, response) = try await urlSession.data(for: urlRequest)

        // Ensure the response is a valid HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMServiceError.invalidResponse(statusCode: -1)
        }

        // Check for successful status code
        guard (200...299).contains(httpResponse.statusCode) else {
            throw LLMServiceError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        // Attempt to decode the response from the Ollama API
        do {
            let decodedResponse = try JSONDecoder().decode(OllamaLLMResponse.self, from: data)
            return decodedResponse
        } catch {
            throw LLMServiceError.decodingError
        }
    }

    /**
     Sends a request to the Ollama API using a completion handler.

     This method is similar to the asynchronous version but allows for a completion handler to be used
     for handling the result or any errors that may occur during the request.

     - Parameters:
        - request: The `LLMRequest` containing the messages and additional parameters for generating text.
        - completion: A closure that handles the result of the request, either a successful `LLMResponse` or an error.
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
