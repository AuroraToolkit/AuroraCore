//
//  ContextManagerTests.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/24/24.
//

import XCTest
@testable import AuroraCore
@testable import AuroraLLM

final class ContextManagerTests: XCTestCase {

    var contextManager: ContextManager!
    var mockService: MockLLMService!
    var mockService2: MockLLMService!
    var mockFactory: MockLLMServiceFactory!

    override func setUp() {
        super.setUp()
        mockService = MockLLMService(name: "TestService", maxOutputTokens: 4096, expectedResult: .success(MockLLMResponse(text: "Test Output")))
        mockService2 = MockLLMService(name: "TestService", maxOutputTokens: 2048, expectedResult: .success(MockLLMResponse(text: "Test Output")))

        mockFactory = MockLLMServiceFactory()
        mockFactory.registerMockService(mockService)
        mockFactory.registerMockService(mockService2)

        contextManager = ContextManager(llmServiceFactory: mockFactory)
    }

    override func tearDown() {
        // Clear out saved context files after each test
        let fileManager = FileManager.default

        do {
            let documentDirectory = try FileManager.default.createContextsDirectory()
            let contextFiles = try fileManager.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil)

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
        let contextID = contextManager.addNewContext(llmService: mockService)

        // Then
        XCTAssertNotNil(contextManager.contextControllers[contextID], "ContextController should be created.")
        XCTAssertNotNil(contextManager.contextControllers[contextID]?.getContext(), "A new context should be created by default.")
        XCTAssertNotNil(contextManager.contextControllers[contextID]?.getSummarizer(), "A default summarizer should be created.")
    }

    // Test adding a new context with a custom context
    func testAddNewContextWithCustomContext() {
        // Given
        let customContext = Context(llmServiceVendor: mockService.vendor)

        // When
        let contextID = contextManager.addNewContext(customContext, llmService: mockService)

        // Then
        XCTAssertEqual(contextManager.contextControllers[contextID]?.getContext(), customContext, "Custom context should be passed to the ContextController.")
    }

    // Test adding a new context with a custom summarizer
    func testAddNewContextWithCustomSummarizer() {
        // Given
        let customSummarizer = MockSummarizer()

        // When
        let contextID = contextManager.addNewContext(llmService: mockService, summarizer: customSummarizer)

        // Then
        XCTAssertEqual(contextManager.contextControllers[contextID]?.getSummarizer() as? MockSummarizer, customSummarizer, "Custom summarizer should be passed to the ContextController.")
    }

    // Test adding a new context with both custom context and summarizer
    func testAddNewContextWithCustomContextAndSummarizer() {
        // Given
        let customContext = Context(llmServiceVendor: mockService.vendor)
        let customSummarizer = MockSummarizer()

        // When
        let contextID = contextManager.addNewContext(customContext, llmService: mockService, summarizer: customSummarizer)

        // Then
        XCTAssertEqual(contextManager.contextControllers[contextID]?.getContext(), customContext, "Custom context should be passed to the ContextController.")
        XCTAssertEqual(contextManager.contextControllers[contextID]?.getSummarizer() as? MockSummarizer, customSummarizer, "Custom summarizer should be passed to the ContextController.")
    }

    // Test that the first context added becomes the active context
    func testFirstContextBecomesActiveContext() {
        // When
        let contextID = contextManager.addNewContext(llmService: mockService)

        // Then
        XCTAssertEqual(contextManager.activeContextID, contextID, "The first context added should become the active context.")
    }

    func testAddNewContextWithoutProvidingContext() {
        // When
        let contextID = contextManager.addNewContext(llmService: mockService)
        let contextController = contextManager.getContextController(for: contextID)

        // Then
        XCTAssertNotNil(contextController?.getContext(), "A new context should be created.")
        XCTAssertEqual(contextManager.contextControllers.count, 1, "ContextManager should contain one context controller.")
    }

    func testAddNewContextWithProvidedContext() {
        // Given
        var preCreatedContext = Context(llmServiceVendor: mockService.vendor)
        preCreatedContext.addItem(content: "Pre-created content")

        // When
        let contextID = contextManager.addNewContext(preCreatedContext, llmService: mockService)
        let contextController = contextManager.getContextController(for: contextID)

        // Then
        XCTAssertEqual(contextController?.getContext().items.count, 1, "Context should contain the pre-created item.")
        XCTAssertEqual(contextController?.getContext().items.first?.text, "Pre-created content", "The content should match the pre-created item.")
    }

    // Test summarizing older contexts in multiple context controllers
    func testSummarizeMultipleContexts() async throws {
        // Given
        let contextID1 = contextManager.addNewContext(llmService: mockService)
        let contextID2 = contextManager.addNewContext(llmService: mockService)

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
        try await contextManager.summarizeOlderContexts()

        // Then
        XCTAssertEqual(contextController1.summarizedContext().count, 1, "Context 1 should have a summarized item.")
        XCTAssertEqual(contextController2.summarizedContext().count, 1, "Context 2 should have a summarized item.")
    }

    // Test saving and loading all contexts
    func testSaveAndLoadAllContexts() async {
        // Given
        let contextID1 = contextManager.addNewContext(llmService: mockService)
        let contextID2 = contextManager.addNewContext(llmService: mockService2)

        guard let contextController1 = contextManager.getContextController(for: contextID1),
            let contextController2 = contextManager.getContextController(for: contextID2) else {
            XCTFail("Context controllers should exist")
            return
        }

        contextController1.addItem(content: "Content for context 1")
        contextController2.addItem(content: "Content for context 2")

        // When
        do {
            try await contextManager.saveAllContexts()
            try await contextManager.loadAllContexts()
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
        let contextID1 = contextManager.addNewContext(llmService: mockService)
        let contextID2 = contextManager.addNewContext(llmService: mockService2)

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
        let contextID1 = contextManager.addNewContext(llmService: mockService)
        let contextID2 = contextManager.addNewContext(llmService: mockService2)

        // When
        contextManager.removeContext(withID: contextID1)

        // Then
        XCTAssertNil(contextManager.getContextController(for: contextID1), "Context controller 1 should be removed.")
        XCTAssertNotNil(contextManager.getContextController(for: contextID2), "Context controller 2 should still exist.")
    }

    // Test setting an active context by its ID
    func testSetActiveContextByID() {
        // Given
        _ = contextManager.addNewContext(llmService: mockService)
        let contextID2 = contextManager.addNewContext(llmService: mockService2)

        // When
        contextManager.setActiveContext(withID: contextID2)

        // Then
        XCTAssertEqual(contextManager.getActiveContextController()?.id, contextID2, "Active context should be set to context 2.")
    }

    // Test summarizing older contexts
    func testSummarizeOlderContexts() async throws {
        // Given
        let contextID1 = contextManager.addNewContext(llmService: mockService)
        let contextID2 = contextManager.addNewContext(llmService: mockService2)

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
        try await contextManager.summarizeOlderContexts()

        // Then
        XCTAssertEqual(contextController1.summarizedContext().count, 1, "Context 1 should have a summarized item.")
        XCTAssertEqual(contextController2.summarizedContext().count, 1, "Context 2 should have a summarized item.")
    }

    // Test loading all contexts
    func testLoadAllContexts() async throws {
        // Given
        let contextID1 = contextManager.addNewContext(llmService: mockService)
        let contextID2 = contextManager.addNewContext(llmService: mockService2)

        guard let contextController1 = contextManager.getContextController(for: contextID1),
            let contextController2 = contextManager.getContextController(for: contextID2) else {
            XCTFail("Context controllers should exist")
            return
        }

        contextController1.addItem(content: "Content for context 1")
        contextController2.addItem(content: "Content for context 2")

        // When
        try await contextManager.saveAllContexts()
        contextManager.removeAllContexts()
        try await contextManager.loadAllContexts()

        // Then
        XCTAssertEqual(contextManager.getContextController(for: contextID1)?.getItems().first?.text, "Content for context 1", "Context 1 should be loaded correctly.")
        XCTAssertEqual(contextManager.getContextController(for: contextID2)?.getItems().first?.text, "Content for context 2", "Context 2 should be loaded correctly.")
    }

    // Test setting an active context with an invalid ID
    func testSetActiveContextWithInvalidID() {
        // Given
        let contextID1 = contextManager.addNewContext(llmService: mockService)
        let invalidContextID = UUID() // Generate a new UUID that is not part of the existing contextControllers

        // When
        contextManager.setActiveContext(withID: invalidContextID)

        // Then
        XCTAssertEqual(contextManager.getActiveContextController()?.id, contextID1, "Active context should not change when an invalid ID is provided.")
    }

    // Test getting active context when there is no active context
    func testGetActiveContextControllerWhenNoActiveContext() {
        // Given
        _ = contextManager.addNewContext(llmService: mockService)

        // Manually set activeContextID to nil to simulate no active context
        contextManager.activeContextID = nil

        // When
        let activeContextController = contextManager.getActiveContextController()

        // Then
        XCTAssertNil(activeContextController, "getActiveContextController() should return nil when no active context is set.")
    }

    // Test loading contexts when there is no active context
    func testLoadAllContextsSetsAnActiveContext() async throws {
        // Given
        let contextID1 = UUID()
        let contextID2 = UUID()

        // Simulate saving two contexts to the file system using SaveContextTask
        var context1 = Context(llmServiceVendor: mockService.vendor)
        context1.addItem(content: "Item in context 1")
        let saveTask1 = SaveContextTask(context: context1, filename: "context_\(contextID1.uuidString)")
        guard case let .task(unwrappedTask1) = saveTask1.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        _ = try await unwrappedTask1.execute()

        var context2 = Context(llmServiceVendor: mockService2.vendor)
        context2.addItem(content: "Item in context 2")
        let saveTask2 = SaveContextTask(context: context2, filename: "context_\(contextID2.uuidString)")
        guard case let .task(unwrappedTask2) = saveTask2.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        _ = try await unwrappedTask2.execute()

        // Ensure no active context is set
        contextManager.activeContextID = nil

        // When
        try await contextManager.loadAllContexts()

        // Then
        XCTAssertEqual(contextManager.contextControllers.count, 2, "There should be two context controllers loaded.")
        XCTAssertNotNil(contextManager.activeContextID, "An active context ID should be set after loading contexts.")

        // Verify that one of the contexts is set as active
        let activeContextItems = contextManager.getActiveContextController()?.getContext().items
        XCTAssertTrue(activeContextItems?.first?.text == "Item in context 1" || activeContextItems?.first?.text == "Item in context 2", "The active context should be one of the loaded contexts.")
    }

    // Test removing all contexts
    func testRemoveAllContexts() {
        // Given
        _ = contextManager.addNewContext(llmService: mockService)
        _ = contextManager.addNewContext(llmService: mockService2)

        // Ensure contexts are added
        XCTAssertEqual(contextManager.contextControllers.count, 2, "There should be two context controllers initially.")
        XCTAssertNotNil(contextManager.activeContextID, "An active context should be set.")

        // When
        contextManager.removeAllContexts()

        // Then
        XCTAssertEqual(contextManager.contextControllers.count, 0, "All context controllers should be removed.")
        XCTAssertNil(contextManager.activeContextID, "The active context ID should be nil after removing all contexts.")
    }

    // Test adding new context after removing all contexts
    func testAddNewContextAfterRemoveAllContexts() {
        // Given
        contextManager.addNewContext(llmService: mockService)
        contextManager.addNewContext(llmService: mockService2)

        // Ensure contexts are added
        XCTAssertEqual(contextManager.contextControllers.count, 2, "There should be two context controllers initially.")

        // Remove all contexts
        contextManager.removeAllContexts()

        // Ensure contexts are removed
        XCTAssertEqual(contextManager.contextControllers.count, 0, "All context controllers should be removed.")
        XCTAssertNil(contextManager.activeContextID, "The active context ID should be nil after removing all contexts.")

        // When
        let newContextID = contextManager.addNewContext(llmService: mockService)

        // Then
        XCTAssertEqual(contextManager.contextControllers.count, 1, "A new context should be added after removing all contexts.")
        XCTAssertEqual(contextManager.activeContextID, newContextID, "The new context should become the active context.")
    }

    // Test removeAllContexts when no context exists
    func testRemoveAllContextsWhenNoContextExists() {
        // Ensure there are no contexts initially
        XCTAssertEqual(contextManager.contextControllers.count, 0, "There should be no context controllers initially.")
        XCTAssertNil(contextManager.activeContextID, "The active context ID should be nil initially.")

        // When
        contextManager.removeAllContexts()

        // Then
        XCTAssertEqual(contextManager.contextControllers.count, 0, "There should still be no context controllers after removing.")
        XCTAssertNil(contextManager.activeContextID, "The active context ID should remain nil.")
    }

    // Test removing a single context and ensuring active context updates correctly
    func testRemoveSingleContext() {
        // Given
        let contextID1 = contextManager.addNewContext(llmService: mockService)
        let contextID2 = contextManager.addNewContext(llmService: mockService2)

        // Ensure contexts are added
        XCTAssertEqual(contextManager.contextControllers.count, 2, "There should be two context controllers initially.")
        XCTAssertEqual(contextManager.activeContextID, contextID1, "The first context should be the active context.")

        // When
        contextManager.removeContext(withID: contextID1)

        // Then
        XCTAssertEqual(contextManager.contextControllers.count, 1, "There should be one context controller remaining.")
        XCTAssertEqual(contextManager.activeContextID, contextID2, "The second context should become the active context after the first one is removed.")
    }
}
