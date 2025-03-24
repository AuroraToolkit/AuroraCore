//
//  QueryTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 3/24/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraLLM
@testable import AuroraTaskLibrary

final class QueryTaskTests: XCTestCase {

    func testQueryTaskReturnsResponseWithCustomParameters() async throws {
        // Given: a mock response and a mock LLM service.
        let expectedResponseText = "This is the answer from the LLM."
        let mockResponse = MockLLMResponse(text: expectedResponseText)
        let mockService = MockLLMService(
            name: "MockLLM",
            expectedResult: .success(mockResponse)
        )

        // Create a QueryTask with a sample query and custom parameters.
        let query = "What is the capital of France?"
        let customSystemPrompt = "You are an expert geographer."
        let customName = "GeographyQuery"
        let customDescription = "Query for geographic information."
        let queryTask = QueryTask(
            name: customName,
            description: customDescription,
            query: query,
            llmService: mockService,
            maxTokens: 50,
            systemPrompt: customSystemPrompt
        )

        // When: executing the query task.
        guard case let .task(task) = queryTask.toComponent() else {
            XCTFail("Expected QueryTask to be a task component.")
            return
        }
        let outputs = try await task.execute()

        // Then: verify that the output matches the expected response.
        XCTAssertEqual(outputs["response"] as? String, expectedResponseText, "The query task should return the expected response.")

        // Additionally, check that the task's name and description are as configured.
        XCTAssertEqual(task.name, customName, "Task name should be as configured.")
        XCTAssertEqual(task.description, customDescription, "Task description should be as configured.")

        // And verify that the mock service received the correct system prompt.
        guard let sentRequest = mockService.receivedRequests.last else {
            XCTFail("No LLM request was sent.")
            return
        }
        let systemMessage = sentRequest.messages.first(where: { $0.role == .system })?.content
        XCTAssertEqual(systemMessage, customSystemPrompt, "The system prompt should match the custom prompt provided.")
    }
}
