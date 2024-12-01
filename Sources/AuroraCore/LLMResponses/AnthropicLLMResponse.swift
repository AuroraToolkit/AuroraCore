//
//  AnthropicLLMResponse.swift
//
//
//  Created by Dan Murrell Jr on 9/15/24.
//

import Foundation

/**
 Represents the response from Anthropic's LLM models, conforming to `LLMResponseProtocol`.

 This struct captures relevant fields from the response, including generated content, message metadata, and token usage statistics if provided by the API.
 */
public struct AnthropicLLMResponse: LLMResponseProtocol, Codable {

    /// The ID of the message returned by the Anthropic API.
    public let id: String

    /// The type of the message.
    public let type: String

    /// The role of the response, usually indicating it's from the assistant.
    public let role: String

    /// The vendor associated with the response.
    public var vendor: String? = "Anthropic"

    /// The model used for generating the response, made optional as per the protocol.
    public var model: String?

    /// The content returned by the Anthropic API.
    public let content: [Content]

    /** The reason why the response was stopped (optional).

     - `end_turn`: the model reached a natural stopping point
     - `max_tokens`: we exceeded the requested `max_tokens` or the model's maximum
     - `stop_sequence`: one of your provided custom stop_sequences was generated
     - `tool_use`: the model invoked one or more tools
     */
    public let stopReason: String?

    /// Token usage statistics (optional).
    public let usage: Usage?

    /// Nested structure to represent the content data.
    public struct Content: Codable {
        /// The type of the content, typically indicating "text".
        let type: String

        /// The text content generated by the model.
        let text: String
    }

    /// Nested structure to represent token usage data (if available).
    public struct Usage: Codable {
        let input_tokens: Int
        let output_tokens: Int
    }

    // MARK: - LLMResponseProtocol Conformance

    /// Returns the concatenated text content from the Anthropic content field.
    public var text: String {
        return content.compactMap { $0.text }.joined()
    }

    /// Returns token usage statistics as an `LLMTokenUsage` object.
    public var tokenUsage: LLMTokenUsage? {
        guard let usage = usage else { return nil }
        return LLMTokenUsage(promptTokens: usage.input_tokens, completionTokens: usage.output_tokens, totalTokens: usage.input_tokens + usage.output_tokens)
    }

    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case role
        case model
        case content
        case stopReason = "stop_reason"
        case usage
    }
}
