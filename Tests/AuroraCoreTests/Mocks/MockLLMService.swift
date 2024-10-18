//
//  MockLLMService.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/19/24.
//

import Foundation
import XCTest
@testable import AuroraCore

final class MockLLMService: LLMServiceProtocol {
    let name: String
    var apiKey: String?
    var maxTokenLimit: Int
    private let expectedResult: Result<LLMResponseProtocol, Error>
    private let streamingExpectedResult: String?

    init(name: String, maxTokenLimit: Int = 4096, expectedResult: Result<LLMResponseProtocol, Error>, streamingExpectedResult: String? = nil) {
        self.name = name
        self.maxTokenLimit = maxTokenLimit
        self.expectedResult = expectedResult
        self.streamingExpectedResult = streamingExpectedResult
    }

    /// Non-streaming request handler
    func sendRequest(_ request: LLMRequest) async throws -> LLMResponseProtocol {
        switch expectedResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    /// Streaming request handler
    func sendRequest(_ request: LLMRequest, onPartialResponse: ((String) -> Void)?) async throws -> LLMResponseProtocol {
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
