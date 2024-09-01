//
//  MockLLMService.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/19/24.
//

import Foundation
import XCTest
@testable import AuroraCore

class MockLLMService: LLMServiceProtocol {
    var apiKey: String?
    
    var name: String
    var expectedResult: Result<LLMResponse, Error>

    init(name: String, expectedResult: Result<LLMResponse, Error>) {
        self.name = name
        self.expectedResult = expectedResult
    }

    func sendRequest(_ request: LLMRequest, completion: @escaping (Result<LLMResponse, Error>) -> Void) {
        completion(expectedResult)
    }
}
