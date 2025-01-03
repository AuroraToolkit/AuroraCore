//
//  LLMResponse.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/19/24.
//

import Foundation

/**
 A protocol that defines a common interface for the response of different LLM services.

 Conforming types must implement:
 - `text`: The main textual response generated by the LLM.
 - `model`: The model used to generate the response, if available.
 - `tokenUsage`: Optional token usage data, providing information about token consumption during the request.

 This protocol allows for consistent interaction with different LLM services while accommodating their unique response formats.
 */
public protocol LLMResponseProtocol {
    /// The generated text from the LLM.
    var text: String { get }

    /// The vendor of the LLM service, if available.
    var vendor: String? { get set }

    /// The model used to generate the text, if available.
    var model: String? { get }

    /// Token usage information, if available.
    var tokenUsage: LLMTokenUsage? { get }
}

extension LLMResponseProtocol {
    /// Model responses don't typically include vendor, so this lets us modify the response to set it.
    func changingVendor(to newVendor: String) -> Self {
        var copy = self
        copy.vendor = newVendor
        return copy
    }
}

/**
 A structure representing token usage information.
 This is used to track the number of tokens used for prompts, completions, and the total request.
 */
public struct LLMTokenUsage {
    /// The number of tokens used in the prompt.
    public let promptTokens: Int

    /// The number of tokens used in the completion.
    public let completionTokens: Int

    /// The total number of tokens used in the request.
    public let totalTokens: Int

    /// Initializes the `LLMTokenUsage` with the given token counts.
    public init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}
