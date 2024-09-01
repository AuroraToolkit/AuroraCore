//
//  MockLLMService.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/19/24.
//

import Foundation
import XCTest
@testable import AuroraCore

public class MockLLMService: LLMServiceProtocol {
    public var name: String
    public var apiKey: String?
    private var expectedResult: Result<LLMResponse, Error>

    public init(name: String, expectedResult: Result<LLMResponse, Error>) {
        self.name = name
        self.apiKey = nil
        self.expectedResult = expectedResult
    }

    // Async version of sendRequest
    public func sendRequest(_ request: LLMRequest) async throws -> LLMResponse {
        switch expectedResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    // Completion handler version of sendRequest
    public func sendRequest(_ request: LLMRequest, completion: @escaping (Result<LLMResponse, Error>) -> Void) {
        completion(expectedResult)
    }
}
