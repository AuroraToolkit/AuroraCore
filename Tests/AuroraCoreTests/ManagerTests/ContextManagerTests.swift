//
//  ContextManagerTests.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/24/24.
//

import XCTest
@testable import AuroraCore

final class ContextManagerTests: XCTestCase {

    var contextManager: ContextManager!

    override func setUp() {
        super.setUp()
        contextManager = ContextManager()
    }

    override func tearDown() {
        // Clear out saved context files after each test
        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!

        do {
            let contextFiles = try fileManager.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasPrefix("context_") }

            // Delete each context file
            for file in contextFiles {
                try fileManager.removeItem(at: file)
            }
        } catch {
            XCTFail("Failed to clean up context files in tearDown: \(error)")
        }

        // Also clear contextManager state
        contextManager = nil

        super.tearDown()
    }

    // Test adding a new context with default parameters
    func testAddNewContextWithDefaults() {
        // When
        let contextID = contextManager.addNewContext()

        // Then
        XCTAssertNotNil(contextManager.contextControllers[contextID], "ContextController should be created.")
        XCTAssertNotNil(contextManager.contextControllers[contextID]?.getContext(), "A new context should be created by default.")
        XCTAssertNotNil(contextManager.contextControllers[contextID]?.getSummarizer(), "A default summarizer should be created.")
    }

    // Test adding a new context with a custom context
    func testAddNewContextWithCustomContext() {
        // Given
        let customContext = Context()

        // When
        let contextID = contextManager.addNewContext(customContext)

        // Then
        XCTAssertEqual(contextManager.contextControllers[contextID]?.getContext(), customContext, "Custom context should be passed to the ContextController.")
    }

    // Test adding a new context with a custom summarizer
    func testAddNewContextWithCustomSummarizer() {
        // Given
        let customSummarizer = MockSummarizer()

        // When
        let contextID = contextManager.addNewContext(nil, summarizer: customSummarizer)

        // Then
        XCTAssertEqual(contextManager.contextControllers[contextID]?.getSummarizer() as? MockSummarizer, customSummarizer, "Custom summarizer should be passed to the ContextController.")
    }

    // Test adding a new context with both custom context and summarizer
    func testAddNewContextWithCustomContextAndSummarizer() {
        // Given
        let customContext = Context()
        let customSummarizer = MockSummarizer()

        // When
        let contextID = contextManager.addNewContext(customContext, summarizer: customSummarizer)

        // Then
        XCTAssertEqual(contextManager.contextControllers[contextID]?.getContext(), customContext, "Custom context should be passed to the ContextController.")
        XCTAssertEqual(contextManager.contextControllers[contextID]?.getSummarizer() as? MockSummarizer, customSummarizer, "Custom summarizer should be passed to the ContextController.")
    }

    // Test that the first context added becomes the active context
    func testFirstContextBecomesActiveContext() {
        // When
        let contextID = contextManager.addNewContext()

        // Then
        XCTAssertEqual(contextManager.activeContextID, contextID, "The first context added should become the active context.")
    }

    func testAddNewContextWithoutProvidingContext() {
        // When
        let contextID = contextManager.addNewContext(maxTokenLimit: 4096)
        let contextController = contextManager.getContextController(for: contextID)

        // Then
        XCTAssertNotNil(contextController?.getContext(), "A new context should be created.")
        XCTAssertEqual(contextManager.contextControllers.count, 1, "ContextManager should contain one context controller.")
    }

    func testAddNewContextWithProvidedContext() {
        // Given
        var preCreatedContext = Context()
        preCreatedContext.addItem(content: "Pre-created content")

        // When
        let contextID = contextManager.addNewContext(preCreatedContext, maxTokenLimit: 4096)
        let contextController = contextManager.getContextController(for: contextID)

        // Then
        XCTAssertEqual(contextController?.getContext().items.count, 1, "Context should contain the pre-created item.")
        XCTAssertEqual(contextController?.getContext().items.first?.text, "Pre-created content", "The content should match the pre-created item.")
    }

    // Test summarizing older contexts in multiple context controllers
    func testSummarizeMultipleContexts() {
        // Given
        let contextID1 = contextManager.addNewContext(maxTokenLimit: 4096)
        let contextID2 = contextManager.addNewContext(maxTokenLimit: 4096)

        guard let contextController1 = contextManager.getContextController(for: contextID1),
              let contextController2 = contextManager.getContextController(for: contextID2) else {
            XCTFail("Context controllers should exist")
            return
        }

        // Create old items (older than 7 days)
        let oldDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())!

        contextController1.addItem(content: String(repeating: "Content1 ", count: 1000), creationDate: oldDate) // Large, old content
        contextController2.addItem(content: String(repeating: "Content2 ", count: 1000), creationDate: oldDate) // Large, old content

        // When
        contextManager.summarizeOlderContexts()

        // Then
        XCTAssertEqual(contextController1.summarizedContext().count, 1, "Context 1 should have a summarized item.")
        XCTAssertEqual(contextController2.summarizedContext().count, 1, "Context 2 should have a summarized item.")
    }

    // Test saving and loading all contexts
    func testSaveAndLoadAllContexts() {
        // Given
        let contextID1 = contextManager.addNewContext(maxTokenLimit: 4096)
        let contextID2 = contextManager.addNewContext(maxTokenLimit: 4096)

        guard let contextController1 = contextManager.getContextController(for: contextID1),
              let contextController2 = contextManager.getContextController(for: contextID2) else {
            XCTFail("Context controllers should exist")
            return
        }

        contextController1.addItem(content: "Content for context 1")
        contextController2.addItem(content: "Content for context 2")

        // When
        do {
            try contextManager.saveAllContexts()
            try contextManager.loadAllContexts()
        } catch {
            XCTFail("Saving and loading contexts should not fail")
        }

        // Then
        XCTAssertEqual(contextManager.getContextController(for: contextID1)?.getItems().first?.text, "Content for context 1", "Context 1 should be loaded correctly.")
        XCTAssertEqual(contextManager.getContextController(for: contextID2)?.getItems().first?.text, "Content for context 2", "Context 2 should be loaded correctly.")
    }

    // Test retrieving all context controllers
    func testGetAllContextControllers() {
        // Given
        let contextID1 = contextManager.addNewContext(maxTokenLimit: 4096)
        let contextID2 = contextManager.addNewContext(maxTokenLimit: 2048)

        // When
        let allContextControllers = contextManager.getAllContextControllers()

        // Then
        XCTAssertEqual(allContextControllers.count, 2, "There should be two context controllers.")

        // Check that the context controllers are retrieved correctly
        XCTAssertNotNil(allContextControllers.first { $0.id == contextID1 }, "Context controller 1 should exist.")
        XCTAssertNotNil(allContextControllers.first { $0.id == contextID2 }, "Context controller 2 should exist.")
    }

    // Test removing a context by its ID
    func testRemoveContextByID() {
        // Given
        let contextID1 = contextManager.addNewContext(maxTokenLimit: 4096)
        let contextID2 = contextManager.addNewContext(maxTokenLimit: 2048)

        // When
        contextManager.removeContext(withID: contextID1)

        // Then
        XCTAssertNil(contextManager.getContextController(for: contextID1), "Context controller 1 should be removed.")
        XCTAssertNotNil(contextManager.getContextController(for: contextID2), "Context controller 2 should still exist.")
    }

    // Test setting an active context by its ID
    func testSetActiveContextByID() {
        // Given
        _ = contextManager.addNewContext(maxTokenLimit: 4096)
        let contextID2 = contextManager.addNewContext(maxTokenLimit: 2048)

        // When
        contextManager.setActiveContext(withID: contextID2)

        // Then
        XCTAssertEqual(contextManager.getActiveContextController()?.id, contextID2, "Active context should be set to context 2.")
    }

    // Test summarizing older contexts
    func testSummarizeOlderContexts() {
        // Given
        let contextID1 = contextManager.addNewContext(maxTokenLimit: 4096)
        let contextID2 = contextManager.addNewContext(maxTokenLimit: 2048)

        guard let contextController1 = contextManager.getContextController(for: contextID1),
              let contextController2 = contextManager.getContextController(for: contextID2) else {
            XCTFail("Context controllers should exist")
            return
        }

        // Create old items (older than 7 days)
        let oldDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        contextController1.addItem(content: String(repeating: "Content1 ", count: 1000), creationDate: oldDate)
        contextController2.addItem(content: String(repeating: "Content2 ", count: 1000), creationDate: oldDate)

        // When
        contextManager.summarizeOlderContexts()

        // Then
        XCTAssertEqual(contextController1.summarizedContext().count, 1, "Context 1 should have a summarized item.")
        XCTAssertEqual(contextController2.summarizedContext().count, 1, "Context 2 should have a summarized item.")
    }

    // Test loading all contexts
    func testLoadAllContexts() throws {
        // Given
        let contextID1 = contextManager.addNewContext(maxTokenLimit: 4096)
        let contextID2 = contextManager.addNewContext(maxTokenLimit: 2048)

        guard let contextController1 = contextManager.getContextController(for: contextID1),
              let contextController2 = contextManager.getContextController(for: contextID2) else {
            XCTFail("Context controllers should exist")
            return
        }

        contextController1.addItem(content: "Content for context 1")
        contextController2.addItem(content: "Content for context 2")

        // When
        try contextManager.saveAllContexts()
        contextManager.contextControllers.removeAll()
        try contextManager.loadAllContexts()

        // Then
        XCTAssertEqual(contextManager.getContextController(for: contextID1)?.getItems().first?.text, "Content for context 1", "Context 1 should be loaded correctly.")
        XCTAssertEqual(contextManager.getContextController(for: contextID2)?.getItems().first?.text, "Content for context 2", "Context 2 should be loaded correctly.")
    }

    // Test setting an active context with an invalid ID
    func testSetActiveContextWithInvalidID() {
        // Given
        let contextID1 = contextManager.addNewContext(maxTokenLimit: 4096)
        let invalidContextID = UUID() // Generate a new UUID that is not part of the existing contextControllers

        // When
        contextManager.setActiveContext(withID: invalidContextID)

        // Then
        XCTAssertEqual(contextManager.getActiveContextController()?.id, contextID1, "Active context should not change when an invalid ID is provided.")
    }

    // Test getting active context when there is no active context
    func testGetActiveContextControllerWhenNoActiveContext() {
        // Given
        _ = contextManager.addNewContext(maxTokenLimit: 4096)

        // Manually set activeContextID to nil to simulate no active context
        contextManager.activeContextID = nil

        // When
        let activeContextController = contextManager.getActiveContextController()

        // Then
        XCTAssertNil(activeContextController, "getActiveContextController() should return nil when no active context is set.")
    }

    // Test loading contexts when there is no active context
    func testLoadAllContextsSetsAnActiveContext() throws {
        // Given
        let contextID1 = UUID()
        let contextID2 = UUID()

        // Simulate saving two contexts to the file system
        let storage1 = ContextStorage(filename: "context_\(contextID1.uuidString)")
        let storage2 = ContextStorage(filename: "context_\(contextID2.uuidString)")

        var context1 = Context()
        context1.addItem(content: "Item in context 1")
        var context2 = Context()
        context2.addItem(content: "Item in context 2")

        try storage1?.saveContext(context1)
        try storage2?.saveContext(context2)

        // Ensure no active context is set
        contextManager.activeContextID = nil

        // When
        try contextManager.loadAllContexts()

        // Then
        XCTAssertEqual(contextManager.contextControllers.count, 2, "There should be two context controllers loaded.")
        XCTAssertNotNil(contextManager.activeContextID, "An active context ID should be set after loading contexts.")

        // Verify that one of the contexts is set as active
        let activeContextItems = contextManager.getActiveContextController()?.getContext().items
        XCTAssertTrue(activeContextItems?.first?.text == "Item in context 1" || activeContextItems?.first?.text == "Item in context 2", "The active context should be one of the loaded contexts.")
    }
}
