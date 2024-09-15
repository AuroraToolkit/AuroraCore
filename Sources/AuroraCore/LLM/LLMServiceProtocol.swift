//
//  LLMServiceProtocol.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/19/24.
//

import Foundation

// MARK: - LLMServiceProtocol

/**
 The `LLMServiceProtocol` defines the interface for interacting with different LLM (Language Learning Model) services.

 Conforming types (e.g., `OpenAIService`, `AnthropicService`, `OllamaService`) must implement this protocol to enable communication with their respective LLM backends.

 This protocol ensures that all LLM services handle requests and responses consistently, allowing the client to interact with multiple LLMs in a unified way.

 - Note: Each service can define its own token limits and handle authentication in its unique way.
 */
public protocol LLMServiceProtocol {
    // The name of the LLM service (e.g., "OpenAI", "Anthropic", "Ollama").
    var name: String { get }

    /**
     The API key or authentication token required to interact with the LLM service.

     - Note: Some services, like Ollama, may not require an API key. For others, such as OpenAI, this key is mandatory for authentication.
     */
    var apiKey: String? { get set }

    /**
     The maximum number of tokens allowed in a single request by the LLM service.

     - Important: This value may differ between services. For example, OpenAI may have a higher token limit compared to other LLMs.
     */
    var maxTokenLimit: Int { get }

    /**
     Sends a request to the LLM service asynchronously and returns the response.

     - Parameter request: The `LLMRequest` object containing the prompt and configuration for the LLM.
     - Returns: An `LLMResponseProtocol` containing the text generated by the LLM.
     - Throws: An error if the request fails due to network issues, invalid parameters, or API errors.
     */
    func sendRequest(_ request: LLMRequest) async throws -> LLMResponseProtocol

    /**
     Sends a request to the LLM service and uses a completion handler to return the result.

     This method is a non-async alternative for services that require immediate handling of requests and responses without awaiting.

     - Parameter request: The `LLMRequest` containing the prompt and other parameters.
     - Parameter completion: A completion handler returning either a successful `LLMResponse` or an `Error` if the request fails.
     */
    func sendRequest(_ request: LLMRequest, completion: @escaping (Result<LLMResponseProtocol, Error>) -> Void)
}
