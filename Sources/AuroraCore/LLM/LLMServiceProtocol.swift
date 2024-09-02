//
//  LLMServiceProtocol.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/19/24.
//

import Foundation

// MARK: - LLMServiceProtocol

/// A protocol that defines the interface for interacting with various LLM (Language Learning Model) services.
/// Each service (e.g., OpenAI, Ollama) will conform to this protocol, implementing its own logic for sending and receiving requests.
public protocol LLMServiceProtocol {
    // The name of the service (e.g., "OpenAI", "Ollama").
    var name: String { get }

    // The API key or authentication token for the service.
    var apiKey: String? { get set }

    // The maximum token limit for the service.
    var maxTokenLimit: Int { get }

    /**
     Sends a request to the LLM service and retrieves the response asynchronously.

     - Parameters:
        - request: The `LLMRequest` containing the prompt and parameters to be processed by the LLM.
     - Returns: The `LLMResponse` containing the generated text.
     */
    func sendRequest(_ request: LLMRequest) async throws -> LLMResponse

    /**
     Sends a request to the LLM service and retrieves the response using a completion handler.

     - Parameters:
        - request: The `LLMRequest` containing the prompt and parameters to be processed by the LLM.
        - completion: A closure that handles the result of the request, either a successful `LLMResponse` or an error.
     */
    func sendRequest(_ request: LLMRequest, completion: @escaping (Result<LLMResponse, Error>) -> Void)
}