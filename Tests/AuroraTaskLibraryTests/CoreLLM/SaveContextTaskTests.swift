//
//  SaveContextTaskTests.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 10/25/24.
//

import XCTest
@testable import AuroraCore
@testable import AuroraLLM

final class SaveContextTaskTests: XCTestCase {

    override func setUp() {
        super.setUp()
        do {
            // Set up contexts directory for testing
            let documentDirectory = try FileManager.default.createContextsDirectory()
            FileManager.default.changeCurrentDirectoryPath(documentDirectory.path)
        } catch {
            XCTFail("Failed to set up test environment: \(error)")
        }
    }

    override func tearDownWithError() throws {
        try cleanupTestFiles()
    }

    // Test for successfully saving a context to a specified file
    func testSaveContextSuccess() async throws {
        let context = Context(llmServiceVendor: "TestService")
        let filename = "test_context.json"

        // Initialize and execute the task
        let task = SaveContextTask(context: context, filename: filename)
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        _ = try await unwrappedTask.execute()

        // Verify the file was saved correctly
        let documentDirectory = try FileManager.default.createContextsDirectory()
        let fileURL = documentDirectory.appendingPathComponent(filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Expected file to be saved at \(fileURL.path)")

        // Verify the contents
        let data = try Data(contentsOf: fileURL)
        let loadedContext = try JSONDecoder().decode(Context.self, from: data)
        XCTAssertEqual(loadedContext, context, "Saved context should match original context")
    }

    // Test for invalid `context` input to simulate a failure
    func testSaveContextMissingContextInput() async throws {
        let task = SaveContextTask(context: nil, filename: "test_context")

        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        // Execute and verify the error
        do {
            _ = try await unwrappedTask.execute(inputs: ["context": "A string value which is not a Context"])
            XCTFail("Expected error when executing task without context input")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Invalid inputs for SaveContextTask", "Error should indicate missing context input")
        }
    }

    // Test for invalid `filename` input to simulate a failure
    func testSaveContextMissingFilenameInput() async throws {
        let context = Context(llmServiceVendor: "OpenAI") // Sample context
        let task = SaveContextTask(context: context, filename: nil)

        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        // Execute and verify the error
        do {
            _ = try await unwrappedTask.execute(inputs: ["filename": nil])
            XCTFail("Expected error when executing task without filename input")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Invalid inputs for SaveContextTask", "Error should indicate missing filename input")
        }
    }

    // Helper function to clean up any test files in the `aurora/contexts` directory
    private func cleanupTestFiles() throws {
        let documentDirectory = try FileManager.default.createContextsDirectory()
        let contents = try FileManager.default.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil)
        for file in contents {
            try FileManager.default.removeItem(at: file)
        }
        try FileManager.default.removeItem(at: documentDirectory)
    }
}
