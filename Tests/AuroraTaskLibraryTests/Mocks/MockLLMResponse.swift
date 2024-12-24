//
//  MockLLMResponse.swift
//
//
//  Created by Dan Murrell Jr on 9/15/24.
//

import Foundation
@testable import AuroraCore
@testable import AuroraLLM

/**
 `MockLLMResponse` is a mock implementation of `LLMResponseProtocol` used for testing.
 It allows you to simulate LLM responses without making real API calls.
 */
public struct MockLLMResponse: LLMResponseProtocol {

    /// The mock text content returned by the mock LLM.
    public var text: String

    /// The vendor of the model used for generating the response
    public var vendor: String?

    /// The model name for the mock LLM (optional).
    public var model: String?

    /// Token usage data for the mock response.
    public var tokenUsage: LLMTokenUsage?

    /**
     Initializes a `MockLLMResponse` instance.

     - Parameters:
        - text: The mock text content.
        - vendor: The vendor of the mock LLM.
        - model: The model name (optional).
        - tokenUsage: The mock token usage statistics (optional).
     */
    public init(text: String, vendor: String = "Test Vendor", model: String? = nil, tokenUsage: LLMTokenUsage? = nil) {
        self.text = text
        self.vendor = vendor
        self.model = model
        self.tokenUsage = tokenUsage
    }
}
