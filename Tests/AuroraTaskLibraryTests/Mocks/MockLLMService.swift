//
//  MockLLMService.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/19/24.
//

import Foundation
import XCTest
@testable import AuroraCore
@testable import AuroraLLM

final class MockLLMService: LLMServiceProtocol {
    var name: String
    var vendor: String
    var apiKey: String?
    var requiresAPIKey = false
    var contextWindowSize: Int
    var maxOutputTokens: Int
    var inputTokenPolicy: TokenAdjustmentPolicy
    var outputTokenPolicy: TokenAdjustmentPolicy
    var systemPrompt: String?
    private let expectedResult: Result<LLMResponseProtocol, Error>
    private let streamingExpectedResult: String?

    // Properties to track calls and parameters for verification
    var receivedRequests: [LLMRequest] = []
    var receivedStreamingRequests: [LLMRequest] = []
    var receivedRoutingStrategy: String.TrimmingStrategy?
    var receivedFallbackCount = 0

    init(name: String, vendor: String = "MockLLM", apiKey: String? = nil, requiresAPIKey: Bool = false, contextWindowSize: Int = 8192, maxOutputTokens: Int = 4096, inputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits, outputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits, systemPrompt: String? = nil, expectedResult: Result<LLMResponseProtocol, Error>, streamingExpectedResult: String? = nil) {
        self.name = name
        self.vendor = vendor
        self.apiKey = apiKey
        self.requiresAPIKey = requiresAPIKey
        self.contextWindowSize = contextWindowSize
        self.maxOutputTokens = maxOutputTokens
        self.inputTokenPolicy = inputTokenPolicy
        self.outputTokenPolicy = outputTokenPolicy
        self.systemPrompt = systemPrompt
        self.expectedResult = expectedResult
        self.streamingExpectedResult = streamingExpectedResult
    }

    /// Non-streaming request handler
    func sendRequest(_ request: LLMRequest) async throws -> LLMResponseProtocol {
        // Track received request for verification in tests
        receivedRequests.append(request)

        // Simulate returning the expected result
        switch expectedResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    /// Streaming request handler
    func sendStreamingRequest(_ request: LLMRequest, onPartialResponse: ((String) -> Void)?) async throws -> LLMResponseProtocol {
        // Track received request for streaming verification in tests
        receivedStreamingRequests.append(request)

        if let streamingExpectedResult = streamingExpectedResult, let onPartialResponse = onPartialResponse {
            // Simulate partial response streaming
            onPartialResponse(streamingExpectedResult)
        }

        // Return the final result after partial response simulation
        switch expectedResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}
