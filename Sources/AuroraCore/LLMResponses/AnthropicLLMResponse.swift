//
//  AnthropicLLMResponse.swift
//  
//
//  Created by Dan Murrell Jr on 9/15/24.
//

import Foundation

/**
 Represents the response from Anthropic's LLM models, conforming to `LLMResponseProtocol`.

 Anthropic's API returns a `completion` field, which contains the generated text from the model.
 This struct also captures any relevant token usage statistics if provided by the API.
 */
public struct AnthropicLLMResponse: LLMResponseProtocol, Codable {

    /// The text content returned by the Anthropic API.
    public let completion: String

    /// The model used for generating the response, made optional as per the protocol.
    public var model: String?

    /// Token usage statistics (optional).
    public let usage: Usage?

    /// Nested structure to represent token usage data (if available).
    public struct Usage: Codable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int
    }

    // MARK: - LLMResponseProtocol Conformance

    /// Returns the text content from the Anthropic completion field.
    public var text: String {
        return completion
    }

    /// Returns token usage statistics as an `LLMTokenUsage` object.
    public var tokenUsage: LLMTokenUsage? {
        guard let usage = usage else { return nil }
        return LLMTokenUsage(promptTokens: usage.prompt_tokens, completionTokens: usage.completion_tokens, totalTokens: usage.total_tokens)
    }
}
