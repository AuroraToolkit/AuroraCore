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

    func testServiceRegistration() async {
        // Given
        let mockService = newMockService(id: "1")

        // When
        manager.registerService(mockService, withName: "TestService")

        // Then
        XCTAssertEqual(manager.services.count, 1, "Service count should be 1")
        XCTAssertEqual(manager.activeServiceName, "TestService", "Active service should be the first registered service.")
    }

    func testUnregisterService() async {
        // Given
        let service1 = newMockService(id: "1")
        manager.registerService(service1, withName: "Service1")

        // When
        manager.unregisterService(withName: "Service1")

        // Then
        XCTAssertEqual(manager.services.count, 0, "Service count should be 0 after unregistering")
    }

    func testSettingActiveService() async {
        // Given
        let service1 = newMockService(id: "1")
        let service2 = newMockService(id: "2")

        // When
        manager.registerService(service1, withName: "Service1")
        manager.registerService(service2, withName: "Service2")
        manager.setActiveService(byName: "Service2")

        // Then
        XCTAssertEqual(manager.activeServiceName, "Service2", "Active service should be Service2.")
    }

    func testTokenTrimmingOnRequest() async {
        // Given
        let mockService = MockLLMService(name: "TestService", maxTokenLimit: 20, expectedResult: .success(MockLLMResponse(text: "Test Output")))
        manager.registerService(mockService, withName: "TestService")

        let longMessage = String(repeating: "A", count: 100) // Exceeds token limit
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])

        // When
        let response = await manager.sendRequest(request, strategy: .end)

        // Then
        XCTAssertEqual(response?.text, "Test Output", "Response should be successful with trimmed message content.")
    }

    func testTokenTrimmingWithStartStrategy() async {
        // Given
        let mockService = MockLLMService(name: "TestService", maxTokenLimit: 20, expectedResult: .success(MockLLMResponse(text: "Test Output")))
        manager.registerService(mockService, withName: "TestService")

        let longMessage = String(repeating: "A", count: 100) // Exceeds token limit
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])

        // When
        let response = await manager.sendRequest(request, strategy: .start)

        // Then
        XCTAssertEqual(response?.text, "Test Output", "Response should be successful with trimmed message content.")
    }

    func testTokenTrimmingOnMultipleServices() async {
        // Given
        let service1 = MockLLMService(name: "Service1", maxTokenLimit: 30, expectedResult: .success(MockLLMResponse(text: "Service1 Output")))
        let service2 = MockLLMService(name: "Service2", maxTokenLimit: 50, expectedResult: .success(MockLLMResponse(text: "Service2 Output")))

        manager.registerService(service1, withName: "Service1")
        manager.registerService(service2, withName: "Service2")

        let longMessage = String(repeating: "B", count: 100) // Exceeds token limits for both services

        // When
        let request1 = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])
        manager.setActiveService(byName: "Service1")
        let response1 = await manager.sendRequest(request1, strategy: .middle)

        // Then
        XCTAssertEqual(response1?.text, "Service1 Output", "Service1 should handle trimmed message content")

        let request2 = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])
        manager.setActiveService(byName: "Service2")
        let response2 = await manager.sendRequest(request2, strategy: .end)

        // Then
        XCTAssertEqual(response2?.text, "Service2 Output", "Service2 should handle trimmed message content")
    }

    func testFallbackServiceWithTokenLimits() async {
        // Given
        let mockService = MockLLMService(name: "TestService", maxTokenLimit: 20, expectedResult: .failure(NSError(domain: "Test", code: 1, userInfo: nil)))
        let fallbackService = MockLLMService(name: "FallbackService", maxTokenLimit: 30, expectedResult: .success(MockLLMResponse(text: "Fallback Output")))

        manager.registerService(mockService, withName: "TestService")
        manager.registerService(fallbackService, withName: "FallbackService")

        let longMessage = String(repeating: "C", count: 100) // Exceeds token limit for TestService but fits in FallbackService

        // When
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])
        let response = await manager.sendRequestWithFallback(request, fallbackServiceName: "FallbackService", strategy: .start)

        // Then
        XCTAssertEqual(response?.text, "Fallback Output", "Should have fallen back to FallbackService and returned correct response.")
    }

    func testBufferedTrimmingWithExactTokenLimit() async {
        // Given
        let mockService = MockLLMService(name: "TestService", maxTokenLimit: 25, expectedResult: .success(MockLLMResponse(text: "Test Output")))
        manager.registerService(mockService, withName: "TestService")

        let longMessage = String(repeating: "D", count: 100) // Exceeds the 25-token adjusted limit

        // When
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])
        let response = await manager.sendRequest(request, strategy: .middle)

        // Then
        XCTAssertEqual(response?.text, "Test Output", "Response should be successful after trimming within buffer.")
    }

    func testSendRequestWithRoutingStrategy() async {
        // Given
        let service1 = MockLLMService(name: "Service1", maxTokenLimit: 25, expectedResult: .success(MockLLMResponse(text: "Service1 Output")))
        let service2 = MockLLMService(name: "Service2", maxTokenLimit: 50, expectedResult: .success(MockLLMResponse(text: "Service2 Output")))

        manager.registerService(service1, withName: "Service1")
        manager.registerService(service2, withName: "Service2")

        let longMessage = String(repeating: "E", count: 100) // Exceeds the limit of Service1 but not Service2

        // When
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])
        let response = await manager.sendRequestWithRouting(request, usingRoutingStrategy: .tokenLimit)

        // Then
        XCTAssertEqual(response?.text, "Service2 Output", "Should have routed to Service2 based on token limit.")
    }

    private func newMockService(id: String) -> MockLLMService {
        MockLLMService(
            name: "MockService\(id)",
            expectedResult: .success(MockLLMResponse(text: "Mock response from Service \(id)"))
        )
    }
}
