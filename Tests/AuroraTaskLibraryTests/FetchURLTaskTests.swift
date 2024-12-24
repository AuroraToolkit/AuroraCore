//
//  FetchURLTaskTests.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/3/24.
//

import XCTest
@testable import AuroraCore
@testable import AuroraLLM
@testable import AuroraTaskLibrary

final class FetchURLTaskTests: XCTestCase {

    var task: FetchURLTask!
    var testServerURL: String!

    override func setUp() {
        super.setUp()
        // Set up a test server or a known good URL
        testServerURL = "https://httpbin.org/get"   // Public API for testing GET requests
    }

    override func tearDown() {
        task = nil
        testServerURL = nil
        super.tearDown()
    }

    func testFetchURLTaskSuccess() async throws {
        // Given
        task = FetchURLTask(url: testServerURL)

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let outputs = try await unwrappedTask.execute()

        // Then
        XCTAssertNotNil(outputs["data"], "The data output should not be nil.")
        if let data = outputs["data"] as? Data {
            XCTAssertFalse(data.isEmpty, "The fetched data should not be empty.")
        }
    }

    func testFetchURLTaskInvalidURL() async throws {
        // Given
        let invalidURL = "invalid-url"
        task = FetchURLTask(url: invalidURL)

        // When/Then
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap the Workflow.Task from the component.")
                return
            }
            _ = try await unwrappedTask.execute()
            XCTFail("Expected an error to be thrown for an invalid URL, but no error was thrown.")
        } catch {
            XCTAssertTrue(error is URLError, "The error should be a URLError.")
        }
    }

    func testFetchURLTaskNonExistentURL() async throws {
        // Given
        let nonExistentURL = "https://thisurldoesnotexist.tld"
        task = FetchURLTask(url: nonExistentURL)

        // When/Then
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap the Workflow.Task from the component.")
                return
            }
            _ = try await unwrappedTask.execute()
            XCTFail("Expected an error to be thrown for a non-existent URL, but no error was thrown.")
        } catch {
            XCTAssertTrue(error is URLError, "The error should be a URLError for a non-existent URL.")
        }
    }

    func testFetchURLTaskWithLargeResponse() async throws {
        // Given
        let largeResponseURL = "https://httpbin.org/bytes/10240" // Generates a 10KB response
        task = FetchURLTask(url: largeResponseURL)

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }
        let outputs = try await unwrappedTask.execute()

        // Then
        XCTAssertNotNil(outputs["data"], "The data output should not be nil.")
        if let data = outputs["data"] as? Data {
            XCTAssertEqual(data.count, 10240, "The fetched data size should match the expected size (10KB).")
        }
    }

    func testFetchURLTaskTimeout() async throws {
        // Given
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 2 // 2-second timeout
        let timeoutURL = "https://httpbin.org/delay/10" // Delays response by 10 seconds
        let session = URLSession(configuration: config)
        task = FetchURLTask(url: timeoutURL, session: session)

        // When/Then
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap the Workflow.Task from the component.")
                return
            }
            _ = try await unwrappedTask.execute()
            XCTFail("Expected a timeout error to be thrown, but no error was thrown.")
        } catch {
            XCTAssertTrue(error is URLError, "The error should be a URLError for a timeout.")
        }
    }
}
