//
//  LLMServiceFactory.swift
//  
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

public class LLMServiceFactory {
    
    public static func createService(for context: Context) -> LLMServiceProtocol? {
        guard let apiKey = SecureStorage.getAPIKey(for: context.llmServiceName) else {
            return nil
        }

        switch context.llmServiceName {
        case "OpenAI":
            return OpenAIService(apiKey: apiKey)
        case "Anthropic":
            return AnthropicService(apiKey: apiKey)
        default:
            return nil
        }
    }
}
