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
        let mockService = MockLLMService(
            name: "TestService",
            expectedResult: .success(MockLLMResponse(text: "Mock response from `TestService`"))
        )

        // When
        manager.registerService(mockService)

        // Then
        XCTAssertEqual(manager.services.count, 1, "Service count should be 1")
        XCTAssertEqual(manager.activeServiceName, "TestService".lowercased(), "Active service should be the first registered service.")
    }

    func testUnregisterService() async {
        // Given
        let service1 = MockLLMService(
            name: "Service1",
            expectedResult: .success(MockLLMResponse(text: "Mock response from `Service1`"))
        )
        manager.registerService(service1)

        // When
        manager.unregisterService(withName: "Service1")

        // Then
        XCTAssertEqual(manager.services.count, 0, "Service count should be 0 after unregistering")
    }

    func testSettingActiveService() async {
        // Given
        let service1 = MockLLMService(
            name: "Service1",
            expectedResult: .success(MockLLMResponse(text: "Mock response from `Service1`"))
        )
        let service2 = MockLLMService(
            name: "Service2",
            expectedResult: .success(MockLLMResponse(text: "Mock response from `Service2`"))
        )

        // When
        manager.registerService(service1)
        manager.registerService(service2)
        manager.setActiveService(byName: "Service2")

        // Then
        XCTAssertEqual(manager.activeServiceName, "Service2", "Active service should be Service2.")
    }

    func testTokenTrimmingOnRequest() async {
        // Given
        let mockService = MockLLMService(name: "TestService", maxTokenLimit: 20, expectedResult: .success(MockLLMResponse(text: "Test Output")))
        manager.registerService(mockService)

        let longMessage = String(repeating: "A", count: 100) // Exceeds token limit
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])

        // When
        let response = await manager.sendRequest(request, trimming: .end)

        // Then
        XCTAssertEqual(response?.text, "Test Output", "Response should be successful with trimmed message content.")
    }

    func testTokenTrimmingWithStartStrategy() async {
        // Given
        let mockService = MockLLMService(name: "TestService", maxTokenLimit: 20, expectedResult: .success(MockLLMResponse(text: "Test Output")))
        manager.registerService(mockService)

        let longMessage = String(repeating: "A", count: 100) // Exceeds token limit
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])

        // When
        let response = await manager.sendRequest(request, trimming: .start)

        // Then
        XCTAssertEqual(response?.text, "Test Output", "Response should be successful with trimmed message content.")
    }

    func testTokenTrimmingOnMultipleServices() async {
        // Given
        let service1 = MockLLMService(name: "Service1", maxTokenLimit: 30, expectedResult: .success(MockLLMResponse(text: "Service1 Output")))
        let service2 = MockLLMService(name: "Service2", maxTokenLimit: 50, expectedResult: .success(MockLLMResponse(text: "Service2 Output")))

        manager.registerService(service1)
        manager.registerService(service2)

        // Test 1: Message that fits within Service1's limit after trimming
        let shorterMessage = String(repeating: "B", count: 25 * 4) // Estimated to fit within 30-token limit after trimming
        let request1 = LLMRequest(messages: [LLMMessage(role: .user, content: shorterMessage)])

        let response1 = await manager.sendRequest(request1, trimming: .middle)

        // Then
        XCTAssertEqual(response1?.text, "Service1 Output", "Service1 should handle trimmed message content that fits within its token limit.")

        // Test 2: Message that exceeds Service1's limit but fits within Service2's limit
        let longerMessage = String(repeating: "B", count: 40 * 4) // Exceeds Service1's 30-token limit, fits within Service2's 50-token limit
        let request2 = LLMRequest(messages: [LLMMessage(role: .user, content: longerMessage)])

        let response2 = await manager.sendRequest(request2, trimming: .end)

        // Then
        XCTAssertEqual(response2?.text, "Service2 Output", "Service2 should handle trimmed message content when Service1 limit is exceeded.")
    }
    
    func testFallbackServiceWithTokenLimits() async {
        // Given
        let mockService = MockLLMService(name: "TestService", maxTokenLimit: 20, expectedResult: .failure(NSError(domain: "Test", code: 1, userInfo: nil)))
        let fallbackService = MockLLMService(name: "FallbackService", maxTokenLimit: 30, expectedResult: .success(MockLLMResponse(text: "Fallback Output")))

        manager.registerService(mockService, withRouting: [.tokenLimit])
        manager.registerFallbackService(fallbackService)

        let longMessage = String(repeating: "C", count: 100) // Exceeds token limit for TestService but fits in FallbackService

        // When
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])
        let response = await manager.sendRequest(request, trimming: .start)

        // Then
        XCTAssertEqual(response?.text, "Fallback Output", "Should have fallen back to FallbackService and returned correct response.")
    }

    func testBufferedTrimmingWithExactTokenLimit() async {
        // Given
        let mockService = MockLLMService(name: "TestService", maxTokenLimit: 25, expectedResult: .success(MockLLMResponse(text: "Test Output")))
        manager.registerService(mockService)

        let longMessage = String(repeating: "D", count: 100) // Exceeds the 25-token adjusted limit

        // When
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])
        let response = await manager.sendRequest(request, trimming: .middle)

        // Then
        XCTAssertEqual(response?.text, "Test Output", "Response should be successful after trimming within buffer.")
    }

    func testSendRequestWithRoutingStrategy() async {
        // Given
        let service1 = MockLLMService(name: "Service1", maxTokenLimit: 25, expectedResult: .success(MockLLMResponse(text: "Service1 Output")))
        let service2 = MockLLMService(name: "Service2", maxTokenLimit: 50, expectedResult: .success(MockLLMResponse(text: "Service2 Output")))

        manager.registerService(service1)
        manager.registerService(service2)

        let longMessage = String(repeating: "E", count: 26 * 4) // Exceeds the limit of Service1 but not Service2

        // When
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])
        let response = await manager.sendRequest(request, routing: .tokenLimit)

        // Then
        XCTAssertEqual(response?.text, "Service2 Output", "Should have routed to Service2 based on token limit.")
    }

    func testStreamingRequest() async {
        // Given
        let streamingResultText = "Partial response from streaming"
        let finalResponseText = "Streaming Response"
        let mockService = MockLLMService(
            name: "StreamingService",
            maxTokenLimit: 50,
            expectedResult: .success(MockLLMResponse(text: finalResponseText)),
            streamingExpectedResult: streamingResultText
        )
        manager.registerService(mockService)

        let message = "This is a streaming test message."
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: message)])

        var partialResponses = [String]()
        let onPartialResponse: (String) -> Void = { response in
            partialResponses.append(response)
        }

        // When
        let response = await manager.sendStreamingRequest(request, onPartialResponse: onPartialResponse)

        // Then
        XCTAssertEqual(response?.text, finalResponseText, "Expected final streaming response text")
        XCTAssertEqual(partialResponses, [streamingResultText], "Expected partial responses to contain the streaming expected result")
    }

    func testTokenLimitRouting() async {
        // Given
        let limitedService = MockLLMService(name: "LimitedService", maxTokenLimit: 20, expectedResult: .success(MockLLMResponse(text: "Limited Response")))
        let extendedService = MockLLMService(name: "ExtendedService", maxTokenLimit: 100, expectedResult: .success(MockLLMResponse(text: "Extended Response")))

        manager.registerService(limitedService)
        manager.registerService(extendedService)

        let longMessage = String(repeating: "X", count: 40 * 4) // Exceeds 20 tokens but within 100 tokens
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])

        // When
        let response = await manager.sendRequest(request, routing: .tokenLimit)

        // Then
        XCTAssertEqual(response?.text, "Extended Response", "Should route to the service with a higher token limit")
    }

    func testDomainRouting() async {
        // Given
        let generalService = MockLLMService(name: "GeneralService", expectedResult: .success(MockLLMResponse(text: "General Response")))
        let specializedService = MockLLMService(name: "SpecializedService", expectedResult: .success(MockLLMResponse(text: "Specialized Response")))

        manager.registerService(generalService, withRouting: [.domain(["general"])])
        manager.registerService(specializedService, withRouting: [.domain(["specialized"])])

        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "Message for specialized domain")])

        // When
        let response = await manager.sendRequest(request, routing: .domain(["specialized"]))

        // Then
        XCTAssertEqual(response?.text, "Specialized Response", "Should route to the specialized service based on domain")
    }

    func testFallbackRouting() async {
        // Given
        let primaryService = MockLLMService(name: "PrimaryService", maxTokenLimit: 20, expectedResult: .failure(NSError(domain: "Test", code: 1)))
        let fallbackService = MockLLMService(name: "FallbackService", maxTokenLimit: 30, expectedResult: .success(MockLLMResponse(text: "Fallback Response")))

        manager.registerService(primaryService, withRouting: [.tokenLimit])
        manager.registerFallbackService(fallbackService)

        let message = String(repeating: "F", count: 25 * 4) // Exceeds PrimaryService limit
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: message)])

        // When
        let response = await manager.sendRequest(request)

        // Then
        XCTAssertEqual(response?.text, "Fallback Response", "Should route to the fallback service")
    }

    func testStartTrimming() async {
        // Given
        let mockService = MockLLMService(name: "TrimStartService", maxTokenLimit: 20, expectedResult: .success(MockLLMResponse(text: "Trimmed Start Response")))
        manager.registerService(mockService)

        let longMessage = String(repeating: "S", count: 50 * 4) // Well beyond 20 tokens
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])

        // When
        let response = await manager.sendRequest(request, trimming: .start)

        // Then
        XCTAssertEqual(response?.text, "Trimmed Start Response", "Should trim from the start to fit within the token limit")
    }

    func testMiddleTrimming() async {
        // Given
        let mockService = MockLLMService(name: "TrimMiddleService", maxTokenLimit: 20, expectedResult: .success(MockLLMResponse(text: "Trimmed Middle Response")))
        manager.registerService(mockService)

        let longMessage = String(repeating: "M", count: 50 * 4)
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])

        // When
        let response = await manager.sendRequest(request, trimming: .middle)

        // Then
        XCTAssertEqual(response?.text, "Trimmed Middle Response", "Should trim from the middle to fit within the token limit")
    }

    func testEndTrimming() async {
        // Given
        let mockService = MockLLMService(name: "TrimEndService", maxTokenLimit: 20, expectedResult: .success(MockLLMResponse(text: "Trimmed End Response")))
        manager.registerService(mockService)

        let longMessage = String(repeating: "E", count: 50 * 4)
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])

        // When
        let response = await manager.sendRequest(request, trimming: .end)

        // Then
        XCTAssertEqual(response?.text, "Trimmed End Response", "Should trim from the end to fit within the token limit")
    }

    func testNoTrimming() async {
        // Given
        let mockService = MockLLMService(name: "NoTrimService", maxTokenLimit: 50, expectedResult: .success(MockLLMResponse(text: "Untrimmed Response")))
        manager.registerService(mockService)

        let shorterMessage = String(repeating: "N", count: 40 * 4) // Fits within 50-token limit without trimming
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: shorterMessage)])

        // When
        let response = await manager.sendRequest(request, trimming: .none)

        // Then
        XCTAssertEqual(response?.text, "Untrimmed Response", "Message should be untrimmed and fit within the limit")
    }

    /// Test to verify behavior when there is no fallback service available and the primary service fails.
    func testNoFallbackServiceAvailable() async {
        // Given
        let primaryService = MockLLMService(name: "PrimaryService", maxTokenLimit: 20, expectedResult: .failure(NSError(domain: "TestError", code: 1)))
        manager.registerService(primaryService)

        let message = String(repeating: "F", count: 25 * 4) // Exceeds PrimaryService limit
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: message)])

        // When
        let response = await manager.sendRequest(request)

        // Then
        XCTAssertNil(response, "Expected nil response when no fallback service is available and primary service fails.")
        // You may also check logs here if needed
    }

    /// Test to verify behavior when both primary and fallback services fail.
    func testFallbackServiceFailure() async {
        // Given
        let primaryService = MockLLMService(name: "PrimaryService", maxTokenLimit: 20, expectedResult: .failure(NSError(domain: "PrimaryError", code: 1)))
        let fallbackService = MockLLMService(name: "FallbackService", maxTokenLimit: 30, expectedResult: .failure(NSError(domain: "FallbackError", code: 1)))

        manager.registerService(primaryService)
        manager.registerFallbackService(fallbackService)

        let message = String(repeating: "F", count: 25 * 4) // Exceeds PrimaryService limit but fits FallbackService
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: message)])

        // When
        let response = await manager.sendRequest(request)

        // Then
        XCTAssertNil(response, "Expected nil response when both primary and fallback services fail.")
        // You may also check logs here if needed
    }

    /// Test to ensure fallback routing is activated in `selectService()` when no services meet the routing criteria.
    func testSelectServiceActivatesFallback() async {
        // Given
        let domainService = MockLLMService(name: "DomainService", maxTokenLimit: 50, expectedResult: .success(MockLLMResponse(text: "Domain Response")))
        let fallbackService = MockLLMService(name: "FallbackService", maxTokenLimit: 30, expectedResult: .success(MockLLMResponse(text: "Fallback Response")))

        manager.registerService(domainService, withRouting: [.domain(["otherDomain"])])
        manager.registerFallbackService(fallbackService)

        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "Request for unsupported domain")])

        // When
        let response = await manager.sendRequest(request, routing: .domain(["unmatchedDomain"]))

        // Then
        XCTAssertEqual(response?.text, "Fallback Response", "Expected fallback service to be selected when no other services meet the domain routing criteria.")
    }

    func testNoSuitableServiceFound() async {
        // Given
        let limitedService = MockLLMService(name: "LimitedService", maxTokenLimit: 10, expectedResult: .failure(NSError(domain: "Test", code: 1, userInfo: nil)))

        // Register a service that does not meet the criteria due to its low token limit
        manager.registerService(limitedService, withRouting: [.tokenLimit])

        // Set the active service to this limited service
        manager.setActiveService(byName: "LimitedService")

        // Do not register any fallback service

        // When
        // Create a request that exceeds the token limit of the active and only registered service
        let longMessage = String(repeating: "X", count: 40 * 4) // Exceeds 10 tokens
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])

        // Call `sendRequest` with a routing strategy that cannot be satisfied
        let response = await manager.sendRequest(request)

        // Then
        XCTAssertNil(response, "Expected no suitable service to be found, so response should be nil.")
    }
}
