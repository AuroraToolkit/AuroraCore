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

    /// The generated text returned by the Ollama API.
    public let response: String

    /// The model used for generating the response, made optional as per the protocol.
    public var model: String?

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
