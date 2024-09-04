//
//  LLMServiceFactory.swift
//  
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

public class LLMServiceFactory {

    /**
     Creates an `LLMServiceProtocol` instance based on the context's service name.

     - Parameters:
        - context: The `Context` instance, which contains information about the associated LLM service.
     - Returns: An optional `LLMServiceProtocol` instance if the service name is recognized, otherwise `nil`.
     */
    public func createService(for context: Context) -> LLMServiceProtocol? {
        // Retrieve the API key (if applicable) from secure storage for services like OpenAI or Anthropic
        let apiKey = SecureStorage.getAPIKey(for: context.llmServiceName)

        switch context.llmServiceName {
        case "OpenAI":
            guard let apiKey = apiKey else { return nil }
            return OpenAIService(apiKey: apiKey)

        case "Anthropic":
            guard let apiKey = apiKey else { return nil }
            return AnthropicService(apiKey: apiKey)

        case "Ollama":
            // Ollama typically doesn't need an API key but allows flexible base URLs for local or remote instances.
            // Retrieve the base URL from context metadata or use a default if not provided.
            let baseURLString = SecureStorage.getBaseURL(for: "Ollama") ?? "http://localhost:11400"
            guard let baseURL = URL(string: baseURLString) else { return nil }
            return OllamaService(baseURL: baseURL)

        default:
            return nil
        }
    }
}
