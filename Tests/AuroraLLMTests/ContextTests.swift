//
//  ContextTests.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/21/24.
//

import XCTest
@testable import AuroraCore
@testable import AuroraLLM

final class ContextTests: XCTestCase {

    var context: Context!

    override func setUp() {
        super.setUp()
        context = Context(llmServiceVendor: "openai")
    }

    override func tearDown() {
        context = nil
        super.tearDown()
    }

    // Test that a new Context sets the creationDate correctly
    func testContextCreationDate() {
        // Given
        let expectedDate = Date()

        // When
        let context = Context(llmServiceVendor: "openai", creationDate: expectedDate)

        // Then
        let calendar = Calendar.current
        let roundedExpectedDate = calendar.date(bySetting: .nanosecond, value: 0, of: expectedDate)
        let roundedCreationDate = calendar.date(bySetting: .nanosecond, value: 0, of: context.creationDate)

        XCTAssertEqual(roundedCreationDate, roundedExpectedDate, "The creationDate should be set correctly upon initialization.")
    }

    // Test adding a new item to the context
    func testAddItem() {
        // Given
        let content = "New item"

        // When
        context.addItem(content: content)

        // Then
        XCTAssertEqual(context.items.count, 1)
        XCTAssertEqual(context.items.first?.text, content)
        XCTAssertFalse(context.items.first?.isSummarized ?? true)
    }

    // Test that the context's creationDate persists through encoding and decoding
    func testContextPersistenceWithCreationDate() {
        // Given
        let expectedDate = Date(timeIntervalSince1970: 1000) // Use a fixed timestamp for the test
        context = Context(llmServiceVendor: "openai", creationDate: expectedDate)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Set the encoding and decoding strategy for dates
        encoder.dateEncodingStrategy = .secondsSince1970
        decoder.dateDecodingStrategy = .secondsSince1970

        // When
        do {
            let encodedData = try encoder.encode(context)
            let decodedContext = try decoder.decode(Context.self, from: encodedData)

            // Then
            XCTAssertEqual(decodedContext.creationDate, expectedDate, "The creationDate should persist after encoding and decoding.")
        } catch {
            XCTFail("Failed to encode or decode the context: \(error)")
        }
    }

    // Test adding and retrieving a bookmark
    func testAddBookmark() {
        // Given
        let content = "Item with Bookmark"
        context.addItem(content: content)
        let addedItem = context.items.first!
        let label = "Important Bookmark"

        // When
        context.addBookmark(for: addedItem, label: label)

        // Then
        XCTAssertEqual(context.bookmarks.count, 1)
        XCTAssertEqual(context.bookmarks.first?.label, label)
    }

    // Test removing an item by its index
    func testRemoveItems() {
        // Given
        let content = "Item to be removed"
        context.addItem(content: content)

        // When
        context.removeItems(atOffsets: IndexSet(integer: 0))

        // Then
        XCTAssertEqual(context.items.count, 0)
    }

    // Test updating an item in the context
    func testUpdateItem() {
        // Given
        let originalContent = "Original content"
        context.addItem(content: originalContent)
        var updatedItem = context.items.first!
        updatedItem.text = "Updated content"

        // When
        context.updateItem(updatedItem)

        // Then
        XCTAssertEqual(context.items.first?.text, "Updated content")
    }

    // Test retrieving an item by its ID
    func testGetItemById() {
        // Given
        let content = "Retrieve by ID"
        context.addItem(content: content)
        let addedItem = context.items.first!

        // When
        let retrievedItem = context.getItem(by: addedItem.id)

        // Then
        XCTAssertEqual(retrievedItem?.text, addedItem.text)
    }

    // Test summarizing a range of items
    func testSummarizeItemsInRange() {
        // Given
        let items = ["Item 1", "Item 2", "Item 3"]
        items.forEach { context.addItem(content: $0) }
        let summarizer: (String) -> String = { text in
            return "Summary of \(text.components(separatedBy: "\n").count) items."
        }

        // When
        context.summarizeItemsInRange(range: 0..<2, summarizer: summarizer)

        // Then
        XCTAssertEqual(context.items.count, 2) // 1 summary + 1 non-summarized item
        XCTAssertTrue(context.items.first?.isSummarized ?? false)
        XCTAssertEqual(context.items.first?.text, "Summary of 2 items.")
    }

    // Test persistence of the context by encoding and decoding
    func testContextPersistence() {
        // Given
        let content = "Persistent Item"
        context.addItem(content: content)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // When
        do {
            let encodedData = try encoder.encode(context)
            let decodedContext = try decoder.decode(Context.self, from: encodedData)

            // Then
            XCTAssertEqual(decodedContext.items.count, context.items.count)
            XCTAssertEqual(decodedContext.items.first?.text, context.items.first?.text)
        } catch {
            XCTFail("Failed to encode or decode the context: \(error)")
        }
    }

    func testGetBookmarkByID() {
        // Given
        context.addItem(content: "Item 1")
        let firstItem = context.items.first!

        // Add a bookmark for the first item
        context.addBookmark(for: firstItem, label: "First Bookmark")

        // When
        let retrievedBookmark = context.getBookmark(by: context.bookmarks.first!.id)

        // Then
        XCTAssertNotNil(retrievedBookmark, "The bookmark should be retrieved successfully.")
        XCTAssertEqual(retrievedBookmark?.label, "First Bookmark", "The bookmark label should match.")
    }

    func testGetRecentItems() {
        // Given
        context.addItem(content: "Item 1")
        context.addItem(content: "Item 2")
        context.addItem(content: "Item 3")

        // When
        let recentItems = context.getRecentItems(limit: 2)

        // Then
        XCTAssertEqual(recentItems.count, 2, "There should be 2 recent items.")
        XCTAssertEqual(recentItems.first?.text, "Item 2", "The first recent item should be 'Item 2'.")
        XCTAssertEqual(recentItems.last?.text, "Item 3", "The last recent item should be 'Item 3'.")
    }
}
