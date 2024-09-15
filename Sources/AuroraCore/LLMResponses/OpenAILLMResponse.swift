//
//  OpenAILLMResponse.swift
//
//
//  Created by Dan Murrell Jr on 9/15/24.
//

import Foundation

/**
 Represents the response from OpenAI's LLM models, conforming to `LLMResponseProtocol`.

 The OpenAI API returns a list of choices, and this struct captures the first choice as the primary response.
 It also tracks usage statistics such as prompt and completion tokens.
 */
public struct OpenAILLMResponse: LLMResponseProtocol, Codable {

    /// Nested structure to represent the message and role.
    public struct Choice: Codable {
        public struct Message: Codable {
            let role: String
            let content: String
        }
        let message: Message
    }

    /// An array of choices returned by the OpenAI API.
    public let choices: [Choice]

    /// Token usage statistics.
    public let usage: Usage?

    /// The model used for generating the response.
    public var model: String?

    /// Nested structure to represent token usage data.
    public struct Usage: Codable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int
    }

    // MARK: - LLMResponseProtocol Conformance

    /// Returns the content from the first choice in the response.
    public var text: String {
        return choices.first?.message.content ?? ""
    }

    /// Returns token usage statistics as an `LLMTokenUsage` object.
    public var tokenUsage: LLMTokenUsage? {
        guard let usage = usage else { return nil }
        return LLMTokenUsage(promptTokens: usage.prompt_tokens, completionTokens: usage.completion_tokens, totalTokens: usage.total_tokens)
    }
}
