//
//  LoadContextTaskTests.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 10/25/24.
//

import XCTest
@testable import AuroraCore
@testable import AuroraLLM

final class LoadContextTaskTests: XCTestCase {

    override func setUp() {
        super.setUp()
        do {
            // Ensure contexts directory is set up before each test
            let documentDirectory = try FileManager.default.createContextsDirectory()
            FileManager.default.changeCurrentDirectoryPath(documentDirectory.path)
        } catch {
            XCTFail("Failed to set up test environment: \(error)")
        }
    }

    override func tearDown() {
        super.tearDown()
        do {
            // Clean up the directory after each test
            let documentDirectory = try FileManager.default.createContextsDirectory()
            let contents = try FileManager.default.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil)
            for file in contents {
                try FileManager.default.removeItem(at: file)
            }
        } catch {
            XCTFail("Failed to clean up test environment: \(error)")
        }
    }

    // Test case for loading a valid context from a specific file
    func testLoadContextFromFile() async throws {
        // Create a sample context and save it to disk
        var context = Context(llmServiceVendor: "TestService")
        context.addItem(content: "Test content")
        let filename = "test_context.json"
        try saveContextToFile(context, filename: filename)

        // Initialize and execute the LoadContextTask
        let task = LoadContextTask(filename: filename)
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()

        // Verify the outputs
        if let outputContext = taskOutputs["context"] as? Context {
            XCTAssertEqual(outputContext.id, context.id, "Loaded context should match saved context")
            XCTAssertEqual(outputContext.items.first?.text, context.items.first?.text, "Context item should match")
        } else {
            XCTFail("Expected context output not found")
        }
    }

    // Test case for loading a context from a default file when no filename is provided
    func testLoadContextFromDefaultFile() async throws {
        // Create a sample context and save it to a default file
        var context = Context(llmServiceVendor: "DefaultService")
        context.addItem(content: "Default content")
        let defaultFilename = "default_context.json"
        try saveContextToFile(context, filename: defaultFilename)

        // Initialize and execute the LoadContextTask without specifying a filename
        let task = LoadContextTask()
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()

        // Verify the outputs
        if let outputContext = taskOutputs["context"] as? Context {
            XCTAssertEqual(outputContext.id, context.id, "Loaded context should match saved context")
            XCTAssertEqual(outputContext.items.first?.text, context.items.first?.text, "Context item should match")
        } else {
            XCTFail("Expected context output not found")
        }
    }

    // Test case for handling a non-existent file
    func testLoadContextFromNonExistentFile() async {
        let task = LoadContextTask(filename: "non_existent.json")
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap the Workflow.Task from the component.")
                return
            }

            _ = try await unwrappedTask.execute()
            XCTFail("Expected an error when loading from a non-existent file")
        } catch let error as NSError {
            XCTAssertEqual(error.code, NSFileReadNoSuchFileError, "Error should have the correct code for a missing file")
        }
    }

    // Helper function to save a context to a file
    private func saveContextToFile(_ context: Context, filename: String) throws {
        let documentDirectory = try FileManager.default.createContextsDirectory()
        let fileURL = documentDirectory.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        let data = try encoder.encode(context)
        try data.write(to: fileURL)
    }
}
