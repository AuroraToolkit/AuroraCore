//
//  ContextControllerTests.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/21/24.
//

import XCTest
@testable import AuroraCore

final class ContextControllerTests: XCTestCase {
    var contextController: ContextController!
    var mockService: MockLLMService!

    override func setUp() {
        super.setUp()
        mockService = MockLLMService(name: "TestService", maxTokenLimit: 100, expectedResult: .success(LLMResponse(text: "Test Output")))
        contextController = ContextController(llmService: mockService, summarizer: MockSummarizer())
    }

    override func tearDown() {
        contextController = nil
        super.tearDown()
    }

    func testAddItemToContext() {
        // Given
        let content = "New context item"

        // When
        contextController.addItem(content: content)

        // Then
        XCTAssertEqual(contextController.getItems().count, 1)
        XCTAssertEqual(contextController.getItems().first?.text, content)
    }

    func testAddBookmarkToContext() {
        // Given
        let content = "Item with Bookmark"
        contextController.addItem(content: content)
        let addedItem = contextController.getItems().first!

        // When
        contextController.addBookmark(for: addedItem, label: "Important bookmark")

        // Then
        XCTAssertEqual(contextController.getBookmarks().count, 1)
        XCTAssertEqual(contextController.getBookmarks().first?.label, "Important bookmark")
    }

    func testRemoveItemFromContext() {
        // Given
        let content = "Item to be removed"
        contextController.addItem(content: content)

        // When
        contextController.removeItems(atOffsets: IndexSet(integer: 0))

        // Then
        XCTAssertEqual(contextController.getItems().count, 0)
    }

    func testUpdateContextItem() {
        // Given
        let content = "Original content"
        contextController.addItem(content: content)
        var updatedItem = contextController.getItems().first!
        updatedItem.text = "Updated content"

        // When
        contextController.updateItem(updatedItem)

        // Then
        XCTAssertEqual(contextController.getItems().first?.text, "Updated content")
    }

    func testGetContext() {
        // Given
        let context = Context(llmServiceName: mockService.name)
        let contextController = ContextController(context: context, llmService: mockService)

        // When
        let retrievedContext = contextController.getContext()

        // Then
        XCTAssertEqual(retrievedContext.items.count, context.items.count, "The number of items in the retrieved context should match the original context.")
        XCTAssertEqual(retrievedContext.bookmarks.count, context.bookmarks.count, "The number of bookmarks in the retrieved context should match the original context.")
    }

    func testSummarizeOlderContext() async throws {
        // Given
        let oldItem = ContextItem(text: "Old item", creationDate: Date().addingTimeInterval(-8 * 24 * 60 * 60)) // 8 days old
        let recentItem = ContextItem(text: "Recent item", creationDate: Date())
        contextController.addItem(content: oldItem.text, creationDate: oldItem.creationDate)
        contextController.addItem(content: recentItem.text, creationDate: recentItem.creationDate)

        // When
        try await contextController.summarizeOlderContext()

        // Then
        XCTAssertEqual(contextController.getItems().count, 2) // Original items remain in context
        XCTAssertEqual(contextController.summarizedContext().count, 1) // One summary should be created
        XCTAssertTrue(contextController.getItems().first?.isSummarized ?? false) // The old item should be marked as summarized
        XCTAssertFalse(contextController.getItems()[1].isSummarized) // The recent item should not be summarized
    }

    func testSummarizeGroupWhenTokenLimitReached() async throws {
        // Given
        let content1 = String(repeating: "Item 1 ", count: 10) // 50 tokens
        let content2 = String(repeating: "Item 2 ", count: 10) // 50 tokens
        contextController.addItem(content: content1, creationDate: Date().addingTimeInterval(-8 * 24 * 60 * 60)) // 8 days old
        contextController.addItem(content: content2, creationDate: Date().addingTimeInterval(-8 * 24 * 60 * 60)) // 8 days old

        // When
        try await contextController.summarizeOlderContext()

        // Then
        XCTAssertEqual(contextController.summarizedContext().count, 1, "There should be 1 summary.")
        XCTAssertEqual(contextController.fullHistory().count, 2, "Full history should include 2 original items.")
        XCTAssertTrue(contextController.fullHistory().first?.isSummarized ?? false, "The original items should be marked as summarized.")
    }

    func testFullHistoryRetrieval() async throws {
        // Given
        contextController.addItem(content: "Item 1")
        contextController.addItem(content: "Item 2")

        // When
        let fullHistory = contextController.fullHistory()

        // Then
        XCTAssertEqual(fullHistory.count, 2, "Full history should have 2 items.")
        XCTAssertEqual(fullHistory.first?.text, "Item 1", "The first item in history should be 'Item 1'.")
        XCTAssertEqual(fullHistory.last?.text, "Item 2", "The last item in history should be 'Item 2'.")
    }

    func testSummarizedContextRetrieval() async throws {
        // Given
        var context = Context(llmServiceName: mockService.name)
        let content1 = String(repeating: "Item 1 ", count: 10)
        let content2 = String(repeating: "Item 2 ", count: 1000)
        context.addItem(content: content1, creationDate: Date().addingTimeInterval(-8 * 24 * 60 * 60)) // 8 days old
        context.addItem(content: content2, creationDate: Date().addingTimeInterval(-8 * 24 * 60 * 60)) // 8 days old
        let contextController = ContextController(context: context, llmService: mockService, summarizer: MockSummarizer())

        // When
        try await contextController.summarizeOlderContext()
        let summarizedItems = contextController.summarizedContext()

        // Then
        XCTAssertEqual(summarizedItems.count, 1, "There should be 1 summarized item.")
        XCTAssertEqual(summarizedItems.first?.text, "Summary of 2 items", "The summarized content should reflect the correct number of items summarized.")
    }

    func testSummarizeOlderContextEmpty() async throws {
        // Given an empty context

        // When
        try await contextController.summarizeOlderContext()

        // Then
        XCTAssertEqual(contextController.fullHistory().count, 0, "Full history should remain empty.")
        XCTAssertEqual(contextController.summarizedContext().count, 0, "No summaries should be created for an empty context.")
    }

    func testSummarizeOlderContextAllSummarized() async throws {
        // Given
        var context = Context(llmServiceName: "TestService")
        context.addItem(content: "Old item", creationDate: Date().addingTimeInterval(-8 * 24 * 60 * 60), isSummary: true)
        let contextController = ContextController(context: context, llmService: mockService)

        // When
        try await contextController.summarizeOlderContext()

        // Then
        XCTAssertEqual(contextController.fullHistory().count, 1, "Full history should contain the original summarized item.")
        XCTAssertEqual(contextController.summarizedContext().count, 0, "No additional summaries should be created.")
    }

    func testSummarizeOlderContextNoOldItems() async throws {
        // Given
        let recentItem = ContextItem(text: "Recent item", creationDate: Date())
        contextController.addItem(content: recentItem.text, creationDate: recentItem.creationDate)

        // When
        try await contextController.summarizeOlderContext()

        // Then
        XCTAssertEqual(contextController.fullHistory().count, 1, "Full history should contain the recent item.")
        XCTAssertEqual(contextController.summarizedContext().count, 0, "No summaries should be created when there are no old items.")
    }

    func testSummarizeOlderContextBoundaryTokenLimit() async throws {
        // Given
        let item1 = ContextItem(text: String(repeating: "A", count: 2000), creationDate: Date().addingTimeInterval(-8 * 24 * 60 * 60)) // 8 days old
        let item2 = ContextItem(text: String(repeating: "B", count: 2000), creationDate: Date().addingTimeInterval(-8 * 24 * 60 * 60)) // 8 days old
        contextController.addItem(content: item1.text, creationDate: item1.creationDate)
        contextController.addItem(content: item2.text, creationDate: item2.creationDate)

        // When
        try await contextController.summarizeOlderContext()

        // Then
        XCTAssertEqual(contextController.fullHistory().count, 2, "Full history should contain the original items.")
        XCTAssertEqual(contextController.summarizedContext().count, 1, "A summary should be created for the two items.")
    }

    func testSummarizeOlderContextWithSingleItem() async throws {
        // Given
        let oldItem = ContextItem(text: "Old item", creationDate: Date().addingTimeInterval(-8 * 24 * 60 * 60)) // 8 days old
        contextController.addItem(content: oldItem.text, creationDate: oldItem.creationDate)

        // When
        try await contextController.summarizeOlderContext()

        // Then
        XCTAssertEqual(contextController.summarizedContext().count, 1, "There should be 1 summarized item.")
        XCTAssertEqual(contextController.summarizedContext().first?.text, "Summary", "The single item should be summarized individually.")
        XCTAssertTrue(contextController.getItems().first?.isSummarized ?? false, "The original item should be marked as summarized.")
    }

    func testSummarizeOlderContextWithMultipleItems() async throws {
        // Given
        let oldItem1 = ContextItem(text: "Old item 1", creationDate: Date().addingTimeInterval(-8 * 24 * 60 * 60)) // 8 days old
        let oldItem2 = ContextItem(text: "Old item 2", creationDate: Date().addingTimeInterval(-8 * 24 * 60 * 60)) // 8 days old
        contextController.addItem(content: oldItem1.text, creationDate: oldItem1.creationDate)
        contextController.addItem(content: oldItem2.text, creationDate: oldItem2.creationDate)

        // When
        try await contextController.summarizeOlderContext()

        // Then
        XCTAssertEqual(contextController.summarizedContext().count, 1, "There should be 1 summarized item.")
        XCTAssertEqual(contextController.summarizedContext().first?.text, "Summary of 2 items", "Multiple items should be summarized together.")
        XCTAssertTrue(contextController.getItems().first?.isSummarized ?? false, "The first item should be marked as summarized.")
        XCTAssertTrue(contextController.getItems()[1].isSummarized, "The second item should be marked as summarized.")
    }
}