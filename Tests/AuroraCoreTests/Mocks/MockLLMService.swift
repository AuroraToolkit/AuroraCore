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

    init(name: String, maxTokenLimit: Int = 4096, expectedResult: Result<LLMResponseProtocol, Error>) {
        self.name = name
        self.maxTokenLimit = maxTokenLimit
        self.expectedResult = expectedResult
    }

    func sendRequest(_ request: LLMRequest) async throws -> LLMResponseProtocol {
        switch expectedResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func sendRequest(_ request: LLMRequest, completion: @escaping (Result<LLMResponseProtocol, Error>) -> Void) {
        completion(expectedResult)
    }
}
