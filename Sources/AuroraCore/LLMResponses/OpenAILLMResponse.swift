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
    public struct Choice: Codable {
        public struct Message: Codable {
            let role: String?
            let content: String?
        }
        /// Incremental response during streaming.
        let delta: Message?
        /// Complete response for non-streaming.
        let message: Message?
        /// Reason for completion.
        let finish_reason: String?
    }

    /// Array of choices.
    public let choices: [Choice]

    /// Token usage statistics (optional for streaming).
    public let usage: Usage?

    /// The model used.
    public var model: String?

    /// Token usage structure.
    public struct Usage: Codable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int
    }

    // MARK: - LLMResponseProtocol Conformance

    /// Extracts and concatenates content from streaming or non-streaming responses.
    public var text: String {
        let deltaContent = choices.compactMap { $0.delta?.content }.joined()
        if !deltaContent.isEmpty {
            return deltaContent
        }
        return choices.first?.message?.content ?? ""
    }

    /// Returns token usage.
    public var tokenUsage: LLMTokenUsage? {
        guard let usage = usage else { return nil }
        return LLMTokenUsage(promptTokens: usage.prompt_tokens, completionTokens: usage.completion_tokens, totalTokens: usage.total_tokens)
    }
}
