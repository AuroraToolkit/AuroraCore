//
//  AnthropicStreamingResponse.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 11/18/24.
//

import Foundation

/**
 Represents a streaming response from Anthropic's LLM service.

 This struct captures various components of the streaming response, including content deltas,
 content blocks, and usage statistics. It is designed to handle partial responses
 received incrementally during the streaming process.
 */
public struct AnthropicLLMStreamingResponse: Codable {
    /// The type of the response event (e.g., "content_block_delta", "message_stop").
    public let type: String

    /// The index of the content block this event pertains to, if applicable.
    public let index: Int?

    /// Represents a delta (change) in the response content, such as text updates.
    public let delta: Delta?

    /// Represents a complete content block in the response, such as text or tool use.
    public let contentBlock: ContentBlock?

    /// Represents the usage statistics (e.g., input and output tokens) associated with this event, if available.
    public let usage: Usage?

    /**
     Represents a change (delta) in the response content, such as an update to a partial text.

     The delta typically provides incremental updates to the text or JSON data being streamed.
     */
    public struct Delta: Codable {
        /// The type of the delta (e.g., "text_delta", "input_json_delta").
        public let type: String

        /// The updated text from the model, if the delta is of type `text_delta`.
        public let text: String?

        /// The updated JSON fragment, if the delta is of type `input_json_delta`.
        public let partialJSON: String?

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case partialJSON = "partial_json"
        }
    }

    /**
     Represents a complete content block in the response.

     Content blocks are self-contained pieces of data such as generated text or tool invocation details.
     */
    public struct ContentBlock: Codable {
        /// The type of the content block (e.g., "text", "tool_use").
        public let type: String

        /// The text content, if the content block represents a text response.
        public let text: String?

        /// The unique identifier of the content block, if applicable.
        public let id: String?

        /// The name of the tool, if the content block represents a tool invocation.
        public let name: String?

        /// The input parameters for the tool, if applicable.
        public let input: [String: String]?

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case id
            case name
            case input
        }
    }

    /**
     Represents the usage statistics associated with the response.

     Usage statistics track the number of input and output tokens consumed during the processing of this event.
     */
    public struct Usage: Codable {
        /// The number of input tokens processed up to this point, if available.
        public let inputTokens: Int?

        /// The number of output tokens generated up to this point, if available.
        public let outputTokens: Int?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
        case index
        case delta
        case contentBlock = "content_block"
        case usage
    }
}
