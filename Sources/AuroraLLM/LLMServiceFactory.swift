//
//  LLMServiceFactory.swift
//  
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation
import AuroraCore

/**
 `LLMServiceFactory` is responsible for creating instances of LLM services like OpenAI, Anthropic, and Ollama.

 The factory ensures that the correct service is instantiated based on the service name and retrieves the required API key from the secure storage.

 - Note: This factory can be extended by adding new services to the switch case.
 */
public class LLMServiceFactory {
    /**
     Creates and returns an LLM service for the given context based on the service name.

     The method checks for the API key in `SecureStorage` and uses it to instantiate the appropriate LLM service, such as OpenAI, Anthropic, or Ollama.

     - Parameter context: The context object containing the LLM service name.
     
     - Returns: An instance of the corresponding `LLMServiceProtocol`, or `nil` if the API key is missing or the service is not supported.
     */
    public func createService(for context: Context) -> LLMServiceProtocol? {
        // Retrieve the API key (if applicable) from secure storage for services like OpenAI or Anthropic
        let apiKey = SecureStorage.getAPIKey(for: context.llmServiceVendor)

        switch context.llmServiceVendor {
        case "OpenAI":
            // Create an OpenAI service instance using the retrieved API key
            guard let apiKey = apiKey else { return nil }
            return OpenAIService(name: "OpenAI" + UUID().uuidString, apiKey: apiKey)

        case "Anthropic":
            // Create an Anthropic service instance using the retrieved API key
            guard let apiKey = apiKey else { return nil }
            return AnthropicService(name: "Anthropic" + UUID().uuidString, apiKey: apiKey)

        case "Ollama":
            // Create an Ollama service with flexible baseURL handling
            // Ollama typically doesn't need an API key but allows flexible base URLs for local or remote instances.
            // Retrieve the base URL from context metadata or use a default if not provided.
            let baseURLString = SecureStorage.getBaseURL(for: "Ollama") ?? "http://localhost:11400"
            return OllamaService(name: "Ollama" + UUID().uuidString, baseURL: baseURLString)

        default:
            return nil
        }
    }
}
