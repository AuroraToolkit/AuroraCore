//
//  FetchContextsTaskTests.swift
//  AuroraCoreTests
//
//  Created by Dan Murrell Jr on 10/25/24.
//

import XCTest
@testable import AuroraCore
@testable import AuroraLLM

final class FetchContextsTaskTests: XCTestCase {

    // Initializes the test setup by creating the contexts directory
    override func setUpWithError() throws {
        let documentDirectory = try FileManager.default.createContextsDirectory()
        FileManager.default.changeCurrentDirectoryPath(documentDirectory.path)
    }

    // Cleans up any files created during testing in the `aurora/contexts` directory
    override func tearDownWithError() throws {
        try cleanupTestFiles()
    }

    // Test case for fetching all contexts when multiple JSON files are present
    func testFetchAllContexts() async throws {
        // Create sample files in the contexts directory
        let files = ["context1.json", "context2.json", "not_a_context.txt"]
        try createTestFiles(files)

        // Initialize and execute the task
        let task = FetchContextsTask()
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()

        // Verify the outputs
        if let outputContexts = taskOutputs["contexts"] as? [URL] {
            XCTAssertEqual(outputContexts.count, 2, "Should only fetch JSON files")
            let filenames = outputContexts.map { $0.lastPathComponent }
            XCTAssertTrue(filenames.contains("context1.json") && filenames.contains("context2.json"), "Filenames should match created contexts")
        } else {
            XCTFail("Expected contexts output not found")
        }
    }

    // Test case for fetching specific contexts by filename
    func testFetchSpecificContexts() async throws {
        let files = ["context1.json", "context2.json", "not_a_context.txt"]
        try createTestFiles(files)

        // Specify filenames in inputs and execute the task
        let task = FetchContextsTask(filenames: ["context1.json"])
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()

        // Verify the outputs
        if let outputContexts = taskOutputs["contexts"] as? [URL] {
            print("Output Contexts: \(outputContexts)") // Debugging step
            XCTAssertEqual(outputContexts.count, 1, "Should fetch only the specified context file")
            XCTAssertEqual(outputContexts.first?.lastPathComponent, "context1.json", "Filenames should match specified context")
        } else {
            XCTFail("Expected contexts output not found")
        }
    }

    // Test case for fetching specific contexts by filename without providing the .json extension
    func testFetchSpecificContextsWithoutJSONExtension() async throws {
        let files = ["context1.json", "context2.json", "not_a_context.txt"]
        try createTestFiles(files)

        // Specify filenames in inputs without the `.json` extension and execute the task
        let task = FetchContextsTask(filenames: ["context1"])
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute(inputs: [:])

        // Verify the outputs
        if let outputContexts = taskOutputs["contexts"] as? [URL] {
            XCTAssertEqual(outputContexts.count, 1, "Should fetch only the specified context file")
            XCTAssertEqual(outputContexts.first?.lastPathComponent, "context1.json", "Filenames should match specified context with the .json extension")
        } else {
            XCTFail("Expected contexts output not found")
        }
    }

    // Test case for handling an empty directory
    func testFetchContextsEmptyDirectory() async throws {
        let task = FetchContextsTask()
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()

        if let outputContexts = taskOutputs["contexts"] as? [URL] {
            XCTAssertEqual(outputContexts.count, 0, "No contexts should be fetched from an empty directory")
        } else {
            XCTFail("Expected contexts output not found")
        }
    }

    // Test case for when the specified file doesn't exist (fileExists returns nil)
    func testFetchSpecificContextsFileNotFound() async throws {
        try cleanupTestFiles()

        let task = FetchContextsTask(filenames: ["non_existent_file"])
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()

        if let outputContexts = taskOutputs["contexts"] as? [URL] {
            XCTAssertEqual(outputContexts.count, 0, "No contexts should be fetched when file does not exist")
        } else {
            XCTFail("Expected contexts output not found")
        }
    }

    // Invalid Filenames in Inputs Test
    func testInvalidFilenamesInInputs() async throws {
        // Given
        let invalidFilenames = ["invalid/name", "another|invalid:name"]
        let task = FetchContextsTask(filenames: invalidFilenames)

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()

        // Then
        if let outputContexts = taskOutputs["contexts"] as? [URL] {
            XCTAssertEqual(outputContexts.count, 0, "No contexts should be fetched for invalid filenames.")
        } else {
            XCTFail("Expected contexts output not found")
        }
    }

    // Mixed Case Filenames Test
    func testMixedCaseFilenames() async throws {
        // Given
        let files = ["Context1.JSON", "context2.json"]
        try createTestFiles(files)

        // Request the file with a different case
        let task = FetchContextsTask(filenames: ["context1.json"])
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()

        // Then
        if let outputContexts = taskOutputs["contexts"] as? [URL] {
            XCTAssertEqual(outputContexts.count, 1, "Should fetch the file regardless of case sensitivity.")
            XCTAssertEqual(outputContexts.first?.lastPathComponent.lowercased(), "context1.json", "File matching should be case insensitive.")
        } else {
            XCTFail("Expected contexts output not found")
        }
    }

    // Performance Test for Large Number of Files
    func testPerformanceForLargeNumberOfFiles() async throws {
        // Given
        let fileCount = 1000
        let filenames = (1...fileCount).map { "context\($0).json" }
        try createTestFiles(filenames)

        let task = FetchContextsTask()

        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let taskOutputs = try await unwrappedTask.execute()
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime

        // Then
        if let outputContexts = taskOutputs["contexts"] as? [URL] {
            XCTAssertEqual(outputContexts.count, fileCount, "Should fetch all \(fileCount) JSON files.")
            XCTAssertLessThan(executionTime, 5.0, "Task should complete within 5 seconds for 1000 files.")
        } else {
            XCTFail("Expected contexts output not found")
        }
    }

    // Helper function to create test files in the `aurora/contexts` directory
    private func createTestFiles(_ filenames: [String]) throws {
        let documentDirectory = try FileManager.default.createContextsDirectory()
        for filename in filenames {
            let fileURL = documentDirectory.appendingPathComponent(filename)
            try "Sample content".write(to: fileURL, atomically: true, encoding: .utf8)
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
