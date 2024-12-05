//
//  FetchContextsTaskTests.swift
//  AuroraCoreTests
//
//  Created by Dan Murrell Jr on 10/25/24.
//

import XCTest
@testable import AuroraCore

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
        let taskOutputs = try await task.execute()

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
        let taskOutputs = try await task.execute()

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
        let taskOutputs = try await task.execute()

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
        let taskOutputs = try await task.execute()

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
        let taskOutputs = try await task.execute()

        if let outputContexts = taskOutputs["contexts"] as? [URL] {
            XCTAssertEqual(outputContexts.count, 0, "No contexts should be fetched when file does not exist")
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
