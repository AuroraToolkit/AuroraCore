//
//  AnthropicService.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/// A stubbed service for interacting with Anthropic's language models.
public class AnthropicService: LLMServiceProtocol {
    public let name = "Anthropic"
    public var apiKey: String?
    public let maxTokenLimit = 8192  // Example token limit

    /**
     Initializes a new instance of `AnthropicService`.

     - Parameter apiKey: The API key used to authenticate with Anthropic's services.
     */
    public init(apiKey: String?) {
        self.apiKey = apiKey

        if let apiKey {
            SecureStorage.saveAPIKey(apiKey, for: name)
        }
    }

    public func sendRequest(_ request: LLMRequest) async throws -> LLMResponse {
        // Stubbed response, just return a dummy LLMResponse
        return LLMResponse(text: "Stubbed response from AnthropicService")
    }

    public func sendRequest(_ request: LLMRequest, completion: @escaping (Result<LLMResponse, Error>) -> Void) {
        // Stubbed response, just return a dummy LLMResponse
        completion(.success(LLMResponse(text: "Stubbed response from AnthropicService")))
    }
}
