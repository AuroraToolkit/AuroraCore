//
//  OllamaLLMResponse.swift
//  
//
//  Created by Dan Murrell Jr on 9/15/24.
//

import Foundation

/**
 Represents the response from Ollama's LLM models, conforming to `LLMResponseProtocol`.

 The Ollama API returns a generated text directly in the `response` field, along with model metadata.
 */
public struct OllamaLLMResponse: LLMResponseProtocol, Codable {

    /// The model used for generating the response, made optional as per the protocol.
    public var model: String?

    ///  The timestamp when the response was created.
    public var created_at: String

    /// The generated text returned by the Ollama API.
    public let response: String

    /// A boolean indicating if the model has finished generating the response.
    public let done: Bool

    /// The number of tokens in the generated response.
    public let eval_count: Int?

    /// Token usage is not provided in the Ollama API, so it's `nil`.
    public var tokenUsage: LLMTokenUsage? {
        return nil
    }

    // MARK: - LLMResponseProtocol Conformance

    /// Returns the generated text content from the Ollama response.
    public var text: String {
        return response
    }
}
