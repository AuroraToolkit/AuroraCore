//
//  OpenAIService.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/// A stubbed service for interacting with OpenAI's language models.
public class OpenAIService: LLMServiceProtocol {
    public let name = "OpenAI"
    public var apiKey: String?
    public let maxTokenLimit = 4096  // Example token limit

    /**
     Initializes a new instance of `OpenAIService`.

     - Parameter apiKey: The API key used to authenticate with OpenAI's services.
     */
    public init(apiKey: String?) {
        self.apiKey = apiKey

        if let apiKey {
            SecureStorage.saveAPIKey(apiKey, for: name)
        }
    }

    public func sendRequest(_ request: LLMRequest) async throws -> LLMResponse {
        // Stubbed response, just return a dummy LLMResponse
        return LLMResponse(text: "Stubbed response from OpenAIService")
    }

    public func sendRequest(_ request: LLMRequest, completion: @escaping (Result<LLMResponse, Error>) -> Void) {
        // Stubbed response, just return a dummy LLMResponse
        completion(.success(LLMResponse(text: "Stubbed response from OpenAIService")))
    }
}
