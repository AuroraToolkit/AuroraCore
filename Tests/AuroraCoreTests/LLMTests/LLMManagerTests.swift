//
//  LLMManagerTests.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/19/24.
//

import XCTest
@testable import AuroraCore

final class LLMManagerTests: XCTestCase {

    var manager: LLMManager!

    override func setUp() {
        super.setUp()
        manager = LLMManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    func testServiceRegistration() {
        // Given
        let mockService = MockLLMService(name: "TestService", maxTokenLimit: 4096, expectedResult: .success(MockLLMResponse(text: "Test Output")))

        // When
        manager.registerService(mockService, withName: "TestService")

        // Then
        XCTAssertEqual(manager.services.count, 1, "Service count should be 1")
        XCTAssertEqual(manager.activeServiceName, "TestService", "Active service should be the first registered service.")
    }

    func testSettingActiveService() {
        // Given
        let service1 = MockLLMService(name: "Service1", maxTokenLimit: 4096, expectedResult: .success(MockLLMResponse(text: "Service1 Output")))
        let service2 = MockLLMService(name: "Service2", maxTokenLimit: 2048, expectedResult: .success(MockLLMResponse(text: "Service2 Output")))

        // When
        manager.registerService(service1, withName: "Service1")
        manager.registerService(service2, withName: "Service2")
        manager.setActiveService(byName: "Service2")

        // Then
        XCTAssertEqual(manager.activeServiceName, "Service2", "Active service should be Service2.")
    }

    func testTokenTrimmingOnRequest() {
        // Given
        let mockService = MockLLMService(name: "TestService", maxTokenLimit: 20, expectedResult: .success(MockLLMResponse(text: "Test Output")))
        manager.registerService(mockService, withName: "TestService")

        let longPrompt = String(repeating: "A", count: 100) // More than 20 tokens

        // When
        let request = LLMRequest(prompt: longPrompt)
        manager.sendRequest(request, strategy: .end) { response in
            // Then
            XCTAssertEqual(response?.text, "Test Output", "Response should be successful with trimmed prompt.")
        }
    }

    func testTokenTrimmingWithStartStrategy() {
        // Given
        let mockService = MockLLMService(name: "TestService", maxTokenLimit: 20, expectedResult: .success(MockLLMResponse(text: "Test Output")))
        manager.registerService(mockService, withName: "TestService")

        let longPrompt = String(repeating: "A", count: 100) // More than 20 tokens

        // When
        let request = LLMRequest(prompt: longPrompt)
        manager.sendRequest(request, strategy: .start) { response in
            // Then
            XCTAssertEqual(response?.text, "Test Output", "Response should be successful with trimmed prompt.")
        }
    }

    func testTokenTrimmingOnMultipleServices() {
        // Given
        let service1 = MockLLMService(name: "Service1", maxTokenLimit: 30, expectedResult: .success(MockLLMResponse(text: "Service1 Output")))
        let service2 = MockLLMService(name: "Service2", maxTokenLimit: 50, expectedResult: .success(MockLLMResponse(text: "Service2 Output")))

        manager.registerService(service1, withName: "Service1")
        manager.registerService(service2, withName: "Service2")

        let longPrompt = String(repeating: "B", count: 100)

        // When
        let request1 = LLMRequest(prompt: longPrompt)
        manager.setActiveService(byName: "Service1")
        manager.sendRequest(request1, strategy: .middle) { response in
            XCTAssertEqual(response?.text, "Service1 Output", "Service1 should handle trimmed prompt")
        }

        let request2 = LLMRequest(prompt: longPrompt)
        manager.setActiveService(byName: "Service2")
        manager.sendRequest(request2, strategy: .end) { response in
            XCTAssertEqual(response?.text, "Service2 Output", "Service2 should handle trimmed prompt")
        }
    }

    func testFallbackServiceWithTokenLimits() {
        // Given
        let mockService = MockLLMService(name: "TestService", maxTokenLimit: 20, expectedResult: .failure(NSError(domain: "Test", code: 1, userInfo: nil)))
        let fallbackService = MockLLMService(name: "FallbackService", maxTokenLimit: 30, expectedResult: .success(MockLLMResponse(text: "Fallback Output")))

        manager.registerService(mockService, withName: "TestService")
        manager.registerService(fallbackService, withName: "FallbackService")

        let longPrompt = String(repeating: "C", count: 100)

        // When
        let request = LLMRequest(prompt: longPrompt)
        manager.sendRequestWithFallback(request, fallbackServiceName: "FallbackService", strategy: .start) { response in
            // Then
            XCTAssertEqual(response?.text, "Fallback Output", "Should have fallen back to FallbackService and returned correct response.")
        }
    }

    func testBufferedTrimmingWithExactTokenLimit() {
        // Given
        let mockService = MockLLMService(name: "TestService", maxTokenLimit: 25, expectedResult: .success(MockLLMResponse(text: "Test Output")))
        manager.registerService(mockService, withName: "TestService")

        let longPrompt = String(repeating: "D", count: 100) // Exceeds the 20-token adjusted limit

        // When
        let request = LLMRequest(prompt: longPrompt)
        manager.sendRequest(request, strategy: .middle) { response in
            // Then
            XCTAssertEqual(response?.text, "Test Output", "Response should be successful after trimming within buffer.")
        }
    }
}
