//
//  LLMResponse.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/19/24.
//

import Foundation

/**
 A struct representing the output generated by the Language Learning Model (LLM) in response to a given `LLMRequest`.
 */
public struct LLMResponse {
    /// The text generated by the LLM in response to the prompt.
    public let text: String

    /**
     Initializes a new `LLMResponse` with the generated text.

     - Parameter text: The text generated by the LLM.
     */
    public init(text: String) {
        self.text = text
    }
}