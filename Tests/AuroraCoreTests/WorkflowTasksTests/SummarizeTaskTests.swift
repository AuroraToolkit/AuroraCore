//
//  SummarizeTaskTests.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 9/2/24.
//

import XCTest
@testable import AuroraCore

final class SummarizeTaskTests: XCTestCase {

    var contextController: ContextController!
    var mockService: MockLLMService!
    var summarizeTask: SummarizeTask!

    override func setUp() {
        super.setUp()
        mockService = MockLLMService(name: "TestService", maxOutputTokens: 4096, expectedResult: .success(MockLLMResponse(text: "Summary")))
        contextController = ContextController(llmService: mockService)
    }

    override func tearDown() {
        summarizeTask = nil
        contextController = nil
        mockService = nil
        super.tearDown()
    }

    func testSummarizeTaskSingleItem() async throws {
        // Given
        contextController.addItem(content: "This is a test content.")
        summarizeTask = SummarizeTask(contextController: contextController, summaryType: .context)

        // When
        try await summarizeTask.execute()

        // Then
        XCTAssertEqual(contextController.getItems().count, 2, "There should be 2 items in the context (original + summary).")
        XCTAssertTrue(contextController.getItems().last?.isSummarized ?? false, "The last item should be marked as a summary.")
        XCTAssertEqual(contextController.getItems().last?.text, "Summary", "The summary text should match the LLM response.")
    }

    func testSummarizeTaskMultipleItems() async throws {
        // Given
        contextController.addItem(content: "First piece of content.")
        contextController.addItem(content: "Second piece of content.")
        summarizeTask = SummarizeTask(contextController: contextController, summaryType: .context)

        // When
        try await summarizeTask.execute()

        // Then
        XCTAssertEqual(contextController.getItems().count, 3, "There should be 3 items in the context (original 2 + summary).")
        XCTAssertTrue(contextController.getItems().last?.isSummarized ?? false, "The last item should be marked as a summary.")
        XCTAssertEqual(contextController.getItems().last?.text, "Summary", "The summary text should match the LLM response.")
    }

    func testSummarizeTaskEmptyContext() async throws {
        // Given
        summarizeTask = SummarizeTask(contextController: contextController, summaryType: .context)

        // When
        try await summarizeTask.execute()

        // Then
        XCTAssertEqual(contextController.getItems().count, 0, "There should be no items in the context.")
        XCTAssertEqual(contextController.summarizedContext().count, 0, "There should be no summaries.")
    }

    func testSummarizeTaskWithFailureResponse() async throws {
        // Given
        let failingService = MockLLMService(name: "FailingService", maxOutputTokens: 4096, expectedResult: .failure(NSError(domain: "Test", code: -1, userInfo: nil)))
        contextController = ContextController(llmService: failingService)
        contextController.addItem(content: "Content that will not be summarized.")
        summarizeTask = SummarizeTask(contextController: contextController, summaryType: .context)

        // When/Then
        do {
            try await summarizeTask.execute()
            XCTFail("Expected an error to be thrown, but no error was thrown.")
        } catch {
            // Verify the error is as expected
            XCTAssertEqual((error as NSError).domain, "Test")
            XCTAssertEqual((error as NSError).code, -1)
        }
    }
    
    func testSummarizeTaskMultipleItemsWithBoundaryCondition() async throws {
        // Given
        let content = String(repeating: "A", count: 4095) // One token short of the limit
        contextController.addItem(content: content)
        contextController.addItem(content: content)
        summarizeTask = SummarizeTask(contextController: contextController, summaryType: .context)

        // When
        try await summarizeTask.execute()

        // Then
        XCTAssertEqual(contextController.getItems().count, 3, "There should be 3 items in the context (original 2 + summary).")
        XCTAssertTrue(contextController.getItems().last?.isSummarized ?? false, "The last item should be marked as a summary.")
        XCTAssertEqual(contextController.getItems().last?.text, "Summary", "The summary text should match the LLM response.")
    }

    func testSummarizeTaskMultipleExecutions() async throws {
        // Given
        contextController.addItem(content: "Content 1")
        contextController.addItem(content: "Content 2")
        summarizeTask = SummarizeTask(contextController: contextController, summaryType: .context)

        // When
        try await summarizeTask.execute()
        try await summarizeTask.execute()

        // Then
        XCTAssertEqual(contextController.getItems().count, 4, "There should be 4 items in the context after 2 summarizations (original 2 + 2 summaries).")
        XCTAssertTrue(contextController.getItems().last?.isSummarized ?? false, "The last item should be marked as a summary.")
        XCTAssertEqual(contextController.getItems().last?.text, "Summary", "The summary text should match the LLM response.")
    }
}
