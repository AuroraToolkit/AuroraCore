//
//  ContextStorageTests.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/22/24.
//

import XCTest
@testable import AuroraCore

final class ContextStorageTests: XCTestCase {

    var contextStorage: ContextStorage!
    var context: Context!
    let testFilename = "test_context"

    override func setUp() {
        super.setUp()

        contextStorage = ContextStorage(filename: testFilename)
        context = Context()
    }

    override func tearDown() {
        contextStorage = nil
        context = nil

        // Remove the test file after each test
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentDirectory.appendingPathComponent("\(testFilename).json")

        try? FileManager.default.removeItem(at: fileURL)

        super.tearDown()
    }

    func testSaveAndLoadContext() throws {
        // Given
        context.addItem(content: "First test item")
        context.addItem(content: "Second test item")

        // When
        try contextStorage.saveContext(context)
        let loadedContext = try contextStorage.loadContext()

        // Then
        XCTAssertEqual(loadedContext.items.count, 2, "Loaded context should contain 2 items")
        XCTAssertEqual(loadedContext.items.first?.text, "First test item", "The first item's content should match")
        XCTAssertEqual(loadedContext.items.last?.text, "Second test item", "The second item's content should match")
    }

    func testLoadEmptyContextFile() {
        // Given: no context file exists

        // When
        do {
            _ = try contextStorage.loadContext()
            XCTFail("Expected to throw an error when loading from a non-existent file.")
        } catch {
            // Then
            XCTAssertTrue(error is CocoaError, "Expected CocoaError when loading from non-existent file.")
        }
    }

    func testSaveContextWithBookmarks() throws {
        // Given
        context.addItem(content: "Bookmark test item")
        let firstItem = context.items.first!
        context.addBookmark(for: firstItem, label: "Test Bookmark")

        // When
        try contextStorage.saveContext(context)
        let loadedContext = try contextStorage.loadContext()

        // Then
        XCTAssertEqual(loadedContext.bookmarks.count, 1, "Loaded context should contain 1 bookmark")
        XCTAssertEqual(loadedContext.bookmarks.first?.label, "Test Bookmark", "The bookmark's label should match")
    }
}
