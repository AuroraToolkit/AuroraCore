//
//  LLMManagerTests.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/19/24.
//

import XCTest
@testable import AuroraCore
@testable import AuroraLLM

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

    func testTokenTrimmingWithStartStrategy() async {
        // Given
        let mockService = MockLLMService(name: "TestService", maxOutputTokens: 100, expectedResult: .success(MockLLMResponse(text: "Test Output")))
        manager.registerService(mockService)

        let longMessage = String(repeating: "A", count: 300) // Exceeds token limit
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)], maxTokens: 30)

        // When
        let response = await manager.sendRequest(request, trimming: .start)

        // Then
        XCTAssertEqual(response?.text, "Test Output", "Response should be successful with trimmed message content.")
    }

    func testFallbackServiceWithTokenLimits() async {
        // Given
        let mockService = MockLLMService(name: "TestService", maxOutputTokens: 20, expectedResult: .failure(NSError(domain: "Test", code: 1, userInfo: nil)))
        let fallbackService = MockLLMService(name: "FallbackService", maxOutputTokens: 30, expectedResult: .success(MockLLMResponse(text: "Fallback Output")))

        manager.registerService(mockService, withRoutings: [.inputTokenLimit(30)])
        manager.registerFallbackService(fallbackService)

        let longMessage = String(repeating: "C", count: 100) // Exceeds token limit for TestService but fits in FallbackService

        // When
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])
        let response = await manager.sendRequest(request, trimming: .start)

        // Then
        XCTAssertEqual(response?.text, "Fallback Output", "Should have fallen back to FallbackService and returned correct response.")
    }

    func testStreamingRequest() async {
        // Given
        let streamingResultText = "Partial response from streaming"
        let finalResponseText = "Streaming Response"
        let mockService = MockLLMService(
            name: "StreamingService",
            maxOutputTokens: 500,
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
        let limitedService = MockLLMService(
            name: "LimitedService",
            maxOutputTokens: 20,
            inputTokenPolicy: .strictRequestLimits,
            outputTokenPolicy: .strictRequestLimits,
            expectedResult: .success(MockLLMResponse(text: "Limited Response")))
        let extendedService = MockLLMService(
            name: "ExtendedService",
            maxOutputTokens: 500,
            inputTokenPolicy: .adjustToServiceLimits,
            outputTokenPolicy: .adjustToServiceLimits,
            expectedResult: .success(MockLLMResponse(text: "Extended Response")))

        manager.registerService(limitedService)
        manager.registerService(extendedService)

        let longMessage = String(repeating: "X", count: 40 * 4) // Exceeds 20 tokens but within 100 tokens
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)])

        // When
        let response = await manager.sendRequest(request, routings: [.inputTokenLimit(30)], trimming: .end)

        // Then
        XCTAssertEqual(response?.text, "Extended Response", "Should route to the service with a higher token limit")
    }

    func testDomainRouting() async {
        // Given
        let generalService = MockLLMService(name: "GeneralService", expectedResult: .success(MockLLMResponse(text: "General Response")))
        let specializedService = MockLLMService(name: "SpecializedService", expectedResult: .success(MockLLMResponse(text: "Specialized Response")))

        manager.registerService(generalService, withRoutings: [.domain(["general"])])
        manager.registerService(specializedService, withRoutings: [.domain(["specialized"])])

        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "Message for specialized domain")])

        // When
        let response = await manager.sendRequest(request, routings: [.domain(["specialized"])])

        // Then
        XCTAssertEqual(response?.text, "Specialized Response", "Should route to the specialized service based on domain")
    }

    func testFallbackRouting() async {
        // Given
        let primaryService = MockLLMService(name: "PrimaryService", maxOutputTokens: 20, expectedResult: .failure(NSError(domain: "Test", code: 1)))
        let fallbackService = MockLLMService(name: "FallbackService", maxOutputTokens: 30, expectedResult: .success(MockLLMResponse(text: "Fallback Response")))

        manager.registerService(primaryService, withRoutings: [.inputTokenLimit(30)])
        manager.registerFallbackService(fallbackService)

        let message = String(repeating: "F", count: 25 * 4) // Exceeds PrimaryService limit
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: message)])

        // When
        let response = await manager.sendRequest(request)

        // Then
        XCTAssertEqual(response?.text, "Fallback Response", "Should route to the fallback service")
    }

    /// Test to verify behavior when there is no fallback service available and the primary service fails.
    func testNoFallbackServiceAvailable() async {
        // Given
        let primaryService = MockLLMService(name: "PrimaryService", maxOutputTokens: 20, expectedResult: .failure(NSError(domain: "TestError", code: 1)))
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
        let primaryService = MockLLMService(name: "PrimaryService", maxOutputTokens: 20, expectedResult: .failure(NSError(domain: "PrimaryError", code: 1)))
        let fallbackService = MockLLMService(name: "FallbackService", maxOutputTokens: 30, expectedResult: .failure(NSError(domain: "FallbackError", code: 1)))

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
        let domainService = MockLLMService(name: "DomainService", maxOutputTokens: 50, expectedResult: .success(MockLLMResponse(text: "Domain Response")))
        let fallbackService = MockLLMService(name: "FallbackService", maxOutputTokens: 30, expectedResult: .success(MockLLMResponse(text: "Fallback Response")))

        manager.registerService(domainService, withRoutings: [.domain(["otherDomain"])])
        manager.registerFallbackService(fallbackService)

        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "Request for unsupported domain")])

        // When
        let response = await manager.sendRequest(request, routings: [.domain(["unmatchedDomain"])])

        // Then
        XCTAssertEqual(response?.text, "Fallback Response", "Expected fallback service to be selected when no other services meet the domain routing criteria.")
    }

    func testNoSuitableServiceFound() async {
        // Given
        let limitedService = MockLLMService(name: "LimitedService", maxOutputTokens: 10, expectedResult: .failure(NSError(domain: "Test", code: 1, userInfo: nil)))

        // Register a service that does not meet the criteria due to its low token limit
        manager.registerService(limitedService, withRoutings: [.inputTokenLimit(10)])

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

    func testInputTokenTrimming() async {
        // Given
        let service = MockLLMService(
            name: "TestService",
            maxOutputTokens: 50,
            expectedResult: .success(MockLLMResponse(text: "Trimmed Input Response"))
        )
        manager.registerService(service, withRoutings: [.inputTokenLimit(40)])

        // Case 1: Input tokens exceed the limit and are trimmed
        let longMessage = String(repeating: "X", count: 60 * 4) // Exceeds 40-token limit
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)], maxTokens: 30)

        // When
        let response = await manager.sendRequest(request, trimming: .end)

        // Then
        XCTAssertEqual(response?.text, "Trimmed Input Response", "Response should succeed with trimmed input tokens.")
    }

    func testOutputTokenLimit() async {
        // Given
        let service = MockLLMService(
            name: "TestService",
            maxOutputTokens: 30,
            expectedResult: .success(MockLLMResponse(text: "Valid Output Response"))
        )
        manager.registerService(service)

        // Case 1: Request with output tokens exceeding service capacity
        let validMessage = String(repeating: "A", count: 10 * 4) // Fits within input limit
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: validMessage)], maxTokens: 50)

        // When
        let response = await manager.sendRequest(request, trimming: .none)

        // Then
        XCTAssertEqual(response?.text, "Valid Output Response", "Service should constrain output tokens to its limit.")
    }

    func testStartTrimming() async {
        // Given
        let service = MockLLMService(
            name: "StartTrimService",
            maxOutputTokens: 20,
            expectedResult: .success(MockLLMResponse(text: "Start Trimmed"))
        )
        manager.registerService(service)

        let longMessage = String(repeating: "S", count: 50 * 4) // Exceeds input limit
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)], maxTokens: 10)

        // When
        let response = await manager.sendRequest(request, trimming: .start)

        // Then
        XCTAssertEqual(response?.text, "Start Trimmed", "Should trim from the start and succeed.")
    }

    func testRoutingBasedOnInputTokens() async {
        // Given
        let service1 = MockLLMService(
            name: "Service1",
            maxOutputTokens: 30,
            inputTokenPolicy: .strictRequestLimits,
            outputTokenPolicy: .strictRequestLimits,
            expectedResult: .success(MockLLMResponse(text: "Service1 Response"))
        )
        let service2 = MockLLMService(
            name: "Service2",
            maxOutputTokens: 50,
            inputTokenPolicy: .adjustToServiceLimits,
            outputTokenPolicy: .adjustToServiceLimits,
            expectedResult: .success(MockLLMResponse(text: "Service2 Response"))
        )

        manager.registerService(service1, withRoutings: [.inputTokenLimit(20)])
        manager.registerService(service2, withRoutings: [.inputTokenLimit(40)])
        manager.setActiveService(byName: "") // Clear active service to ensure proper routing logic

        // Case 1: Fits within Service1's limit
        let shortMessage = String(repeating: "X", count: 15 * 4) // Fits Service1
        let request1 = LLMRequest(messages: [LLMMessage(role: .user, content: shortMessage)], maxTokens: 30)
        let response1 = await manager.sendRequest(request1, routings: [.inputTokenLimit(20)]) // Explicitly use Service1's routing

        // Case 2: Exceeds Service1 but fits Service2
        let longerMessage = String(repeating: "X", count: 35 * 4) // Fits Service2
        let request2 = LLMRequest(messages: [LLMMessage(role: .user, content: longerMessage)], maxTokens: 50)
        let response2 = await manager.sendRequest(request2, routings: [.inputTokenLimit(40)]) // Explicitly use Service2's routing

        // Then
        XCTAssertEqual(response1?.text, "Service1 Response", "Service1 should handle the smaller message.")
        XCTAssertEqual(response2?.text, "Service2 Response", "Service2 should handle the larger message.")
    }

    func testDynamicTokenPolicySwitching() async {
        // Given
        let service = MockLLMService(
            name: "DynamicPolicyService",
            contextWindowSize: 80,
            maxOutputTokens: 50,
            inputTokenPolicy: .strictRequestLimits,
            outputTokenPolicy: .strictRequestLimits,
            expectedResult: .success(MockLLMResponse(text: "Dynamic Policy Response"))
        )
        manager.registerService(service)

        // Case 1: Input exceeds limit with strict policy
        let longMessage = String(repeating: "X", count: 60 * 4) // Exceeds input limit
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)], maxTokens: 50)
        let response1 = await manager.sendRequest(request)

        XCTAssertNil(response1, "Expected nil response with strict policy and input exceeding limits.")

        // Update policies
        service.inputTokenPolicy = .adjustToServiceLimits
        service.outputTokenPolicy = .adjustToServiceLimits
        service.contextWindowSize = 120

        // Case 2: Input exceeds limit but should now be adjusted
        let response2 = await manager.sendRequest(request)

        XCTAssertEqual(response2?.text, "Dynamic Policy Response", "Expected valid response with adjusted policies.")
    }

    func testFallbackServiceWithDynamicTokenPolicySwitching() async {
        // Given
        let primaryService = MockLLMService(
            name: "PrimaryService",
            contextWindowSize: 80, // Smaller context window
            maxOutputTokens: 40,
            inputTokenPolicy: .strictRequestLimits,
            outputTokenPolicy: .strictRequestLimits,
            expectedResult: .failure(NSError(domain: "PrimaryServiceError", code: 1))
        )
        let fallbackService = MockLLMService(
            name: "FallbackService",
            contextWindowSize: 120, // Larger context window
            maxOutputTokens: 60,
            inputTokenPolicy: .adjustToServiceLimits,
            outputTokenPolicy: .adjustToServiceLimits,
            expectedResult: .success(MockLLMResponse(text: "Fallback Service Response"))
        )

        manager.registerService(primaryService)
        manager.registerFallbackService(fallbackService)

        // Case: Request that exceeds the primary service's limits but fits fallback's adjusted limits
        let longMessage = String(repeating: "X", count: 60 * 4) // Exceeds primary's input limit
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)], maxTokens: 50)

        // When
        let response = await manager.sendRequest(request)

        // Then
        XCTAssertNotNil(response, "Expected fallback service to handle the request.")
        XCTAssertEqual(response?.text, "Fallback Service Response", "Expected response from fallback service with adjusted policies.")
    }

    func testRoutingAndPolicyConflictResolution() async {
        // Given
        let serviceWithStrictPolicy = MockLLMService(
            name: "StrictPolicyService",
            contextWindowSize: 100,
            maxOutputTokens: 30,
            inputTokenPolicy: .strictRequestLimits,
            outputTokenPolicy: .strictRequestLimits,
            expectedResult: .success(MockLLMResponse(text: "Strict Policy Response"))
        )
        let serviceWithFlexiblePolicy = MockLLMService(
            name: "FlexiblePolicyService",
            contextWindowSize: 200,
            maxOutputTokens: 50,
            inputTokenPolicy: .adjustToServiceLimits,
            outputTokenPolicy: .adjustToServiceLimits,
            expectedResult: .success(MockLLMResponse(text: "Flexible Policy Response"))
        )

        manager.registerService(serviceWithStrictPolicy, withRoutings: [.domain(["strictDomain"])])
        manager.registerService(serviceWithFlexiblePolicy, withRoutings: [.domain(["flexibleDomain"])])

        // Case: Request satisfies token limit for strict service but not domain
        let request = LLMRequest(
            messages: [LLMMessage(role: .user, content: "Request for flexible domain.")],
            maxTokens: 40 // Exceeds strict output tokens but fits flexible tokens
        )

        // When
        let response = await manager.sendRequest(request, routings: [.domain(["flexibleDomain"])])

        // Then
        XCTAssertEqual(response?.text, "Flexible Policy Response", "Expected routing to flexible policy service based on domain match.")
    }

    func testMultipleServicesWithFallbacksAndConflicts() async {
        // Given
        let service1 = MockLLMService(
            name: "StrictService",
            contextWindowSize: 80,
            maxOutputTokens: 30,
            inputTokenPolicy: .strictRequestLimits,
            outputTokenPolicy: .strictRequestLimits,
            expectedResult: .failure(NSError(domain: "StrictServiceError", code: 1))
        )
        let service2 = MockLLMService(
            name: "FlexibleService",
            contextWindowSize: 100,
            maxOutputTokens: 40,
            inputTokenPolicy: .adjustToServiceLimits,
            outputTokenPolicy: .strictRequestLimits,
            expectedResult: .failure(NSError(domain: "FlexibleServiceError", code: 1))
        )
        let fallbackService = MockLLMService(
            name: "FallbackService",
            contextWindowSize: 120,
            maxOutputTokens: 50,
            inputTokenPolicy: .adjustToServiceLimits,
            outputTokenPolicy: .adjustToServiceLimits,
            expectedResult: .success(MockLLMResponse(text: "Fallback Response"))
        )

        manager.registerService(service1, withRoutings: [.inputTokenLimit(40)])
        manager.registerService(service2, withRoutings: [.inputTokenLimit(60)])
        manager.registerFallbackService(fallbackService)

        let longMessage = String(repeating: "X", count: 90 * 4) // Exceeds both service1 and service2 limits
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longMessage)], maxTokens: 50)

        // When
        let response = await manager.sendRequest(request)

        // Then
        XCTAssertEqual(response?.text, "Fallback Response", "Expected fallback service to handle the request.")
    }

    func testNearBoundaryTokenRequests() async {
        // Given
        let boundaryService = MockLLMService(
            name: "BoundaryService",
            contextWindowSize: 100,
            maxOutputTokens: 50,
            inputTokenPolicy: .adjustToServiceLimits,
            outputTokenPolicy: .adjustToServiceLimits,
            expectedResult: .success(MockLLMResponse(text: "Boundary Response"))
        )
        manager.registerService(boundaryService)

        // Case 1: Request barely within the limits
        let nearLimitMessage = String(repeating: "X", count: 25 * 4) // Fits within input token limit
        let requestWithinLimits = LLMRequest(messages: [LLMMessage(role: .user, content: nearLimitMessage)], maxTokens: 50)

        // Case 2: Request slightly exceeding the limits
        let overLimitMessage = String(repeating: "X", count: 30 * 4) // Exceeds input token limit
        let requestOverLimits = LLMRequest(messages: [LLMMessage(role: .user, content: overLimitMessage)], maxTokens: 60)

        // When
        let responseWithinLimits = await manager.sendRequest(requestWithinLimits)
        let responseOverLimits = await manager.sendRequest(requestOverLimits, trimming: .end)

        // Then
        XCTAssertEqual(responseWithinLimits?.text, "Boundary Response", "Expected successful response for request within limits.")
        XCTAssertEqual(responseOverLimits?.text, "Boundary Response", "Expected successful response with trimmed input.")
    }

    func testInvalidOrMissingConfigurations() async {
        // Given
        let validService = MockLLMService(
            name: "ValidService",
            apiKey: "valid_api_key", // Proper configuration
            requiresAPIKey: true,
            contextWindowSize: 100,
            maxOutputTokens: 50,
            expectedResult: .success(MockLLMResponse(text: "Valid Response"))
        )
        let invalidService = MockLLMService(
            name: "InvalidService",
            apiKey: nil, // Missing API key
            requiresAPIKey: true,
            contextWindowSize: 100,
            maxOutputTokens: 50,
            expectedResult: .failure(NSError(domain: "TestError", code: 1))
        )

        manager.registerService(validService)
        manager.registerService(invalidService)

        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "Test message")])

        // When
        let response = await manager.sendRequest(request)

        // Then
        XCTAssertEqual(response?.text, "Valid Response", "Expected valid service to handle the request.")
    }

    func testStressWithManyServices() async {
        // Given
        let numServices = 20
        for i in 1...numServices {
            let serviceName = "Service\(i)"
            let service = MockLLMService(
                name: serviceName,
                contextWindowSize: 100 + i * 10, // Incremental limits
                maxOutputTokens: 20 + i * 5,
                inputTokenPolicy: .adjustToServiceLimits,
                outputTokenPolicy: .adjustToServiceLimits,
                expectedResult: .success(MockLLMResponse(text: "\(serviceName) Response"))
            )
            manager.registerService(service)
        }

        let testMessage = String(repeating: "A", count: 200) // Will fit into a mid-tier service
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: testMessage)], maxTokens: 50)

        // When
        let response = await manager.sendRequest(request)

        // Then
        XCTAssertNotNil(response, "Expected a response to be returned from one of the services.")
        XCTAssertTrue(response?.text.contains("Service") ?? false, "Expected response to come from a valid service.")
    }

    func testDomainRoutingWithRoutingService() async {
        // Given
        let mockService = MockLLMService(
            name: "MockService",
            expectedResult: .success(MockLLMResponse(text: "Mock Response"))
        )
        let mockRouter = MockLLMDomainRouter(
            name: "MockDomainRouter",
            service: mockService,
            expectedDomain: "sports"
        )
        let sportsService = MockLLMService(
            name: "SportsService",
            expectedResult: .success(MockLLMResponse(text: "Sports Response"))
        )
        let fallbackService = MockLLMService(
            name: "FallbackService",
            expectedResult: .success(MockLLMResponse(text: "Fallback Response"))
        )

        manager.registerDomainRouter(mockRouter)
        manager.registerService(sportsService, withRoutings: [.domain(["sports"])])
        manager.registerFallbackService(fallbackService)

        let sportsQuestion = LLMRequest(messages: [LLMMessage(role: .user, content: "Who won the Super Bowl in 2022?")])

        // When
        let response = await manager.routeRequest(sportsQuestion)

        // Then
        XCTAssertEqual(response?.text, "Sports Response", "Should route to the SportsService based on the identified domain.")
    }

    func testDomainRoutingFallback() async {
        // Given
        let mockService = MockLLMService(
            name: "MockService",
            expectedResult: .success(MockLLMResponse(text: "Mock Response"))
        )
        let mockRouter = MockLLMDomainRouter(
            name: "MockDomainRouter",
            service: mockService,
            expectedDomain: "unknownDomain"
        )
        let fallbackService = MockLLMService(
            name: "FallbackService",
            expectedResult: .success(MockLLMResponse(text: "Fallback Response"))
        )

        manager.registerDomainRouter(mockRouter)
        manager.registerFallbackService(fallbackService)

        let unknownDomainQuestion = LLMRequest(messages: [LLMMessage(role: .user, content: "What's the capital of France?")])

        // When
        let response = await manager.routeRequest(unknownDomainQuestion)

        // Then
        XCTAssertEqual(response?.text, "Fallback Response", "Should route to the fallback service if the domain is unknown.")
    }

    func testDomainRoutingErrorHandling() async {
        // Given
        let mockService = MockLLMService(
            name: "MockService",
            expectedResult: .success(MockLLMResponse(text: "Mock Response"))
        )
        let mockRouter = MockLLMDomainRouter(
            name: "MockDomainRouter",
            service: mockService,
            shouldThrowError: true
        )
        let generalService = MockLLMService(
            name: "GeneralService",
            expectedResult: .success(MockLLMResponse(text: "General Response"))
        )

        manager.registerDomainRouter(mockRouter)
        manager.registerFallbackService(generalService)

        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "What's the capital of France?")])

        // When
        let response = await manager.routeRequest(request)

        // Then
        XCTAssertEqual(response?.text, "General Response", "Should fall back to the general service if the domain routing service fails.")
    }

    func testDomainRoutingWithoutRoutingService() async {
        // Given
        let sportsService = MockLLMService(
            name: "SportsService",
            expectedResult: .success(MockLLMResponse(text: "Sports Response"))
        )
        manager.registerService(sportsService)

        let fallbackService = MockLLMService(
            name: "FallbackService",
            expectedResult: .success(MockLLMResponse(text: "Fallback Response"))
        )
        manager.registerFallbackService(fallbackService)

        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "Who won the Super Bowl in 2022?")])

        // When
        let response = await manager.routeRequest(request)

        // Then
        XCTAssertEqual(response?.text, "Sports Response", "Should route to the active service when no domain routing service is registered.")
    }

    func testDomainRoutingInvalidService() async {
        // Given
        let mockService = MockLLMService(
            name: "MockService",
            expectedResult: .success(MockLLMResponse(text: "Mock Response"))
        )
        let mockRouter = MockLLMDomainRouter(
            name: "MockDomainRouter",
            service: mockService,
            expectedDomain: "invalidDomain"
        )
        let fallbackService = MockLLMService(
            name: "FallbackService",
            expectedResult: .success(MockLLMResponse(text: "Fallback Response"))
        )

        manager.registerDomainRouter(mockRouter)
        manager.registerFallbackService(fallbackService)

        let invalidDomainQuestion = LLMRequest(messages: [LLMMessage(role: .user, content: "What is an invalid domain test?")])

        // When
        let response = await manager.routeRequest(invalidDomainQuestion)

        // Then
        XCTAssertEqual(response?.text, "Fallback Response", "Should route to the fallback service if no registered service matches the identified domain.")
    }
}
