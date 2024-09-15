//
//  MockLLMResponse.swift
//
//
//  Created by Dan Murrell Jr on 9/15/24.
//

import Foundation
import XCTest
@testable import AuroraCore

/**
 `MockLLMResponse` is a mock implementation of `LLMResponseProtocol` used for testing.
 It allows you to simulate LLM responses without making real API calls.
 */
public struct MockLLMResponse: LLMResponseProtocol {

    /// The mock text content returned by the mock LLM.
    public var text: String

    /// The model name for the mock LLM (optional).
    public var model: String?

    /// Token usage data for the mock response.
    public var tokenUsage: LLMTokenUsage?

    /**
     Initializes a `MockLLMResponse` instance.

     - Parameters:
        - text: The mock text content.
        - model: The model name (optional).
        - tokenUsage: The mock token usage statistics (optional).
     */
    public init(text: String, model: String? = nil, tokenUsage: LLMTokenUsage? = nil) {
        self.text = text
        self.model = model
        self.tokenUsage = tokenUsage
    }
}
