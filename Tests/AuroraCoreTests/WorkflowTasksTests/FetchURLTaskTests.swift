//
//  FetchURLTaskTests.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/3/24.
//

import XCTest
@testable import AuroraCore

final class FetchURLTaskTests: XCTestCase {

    var task: FetchURLTask!
    var testServerURL: URL!

    override func setUp() {
        super.setUp()
        // Set up a test server or a known good URL
        testServerURL = URL(string: "https://httpbin.org/get") // Example: public API for testing GET requests
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
        let taskOutputs = try await task.execute()

        // Then
        XCTAssertNotNil(taskOutputs["data"], "The data output should not be nil.")
        if let data = taskOutputs["data"] as? Data {
            XCTAssertFalse(data.isEmpty, "The fetched data should not be empty.")
        }
    }

    func testFetchURLTaskInvalidURL() async throws {
        // Given
        let invalidURL = URL(string: "invalid-url")!
        task = FetchURLTask(url: invalidURL)

        // When/Then
        do {
            _ = try await task.execute()
            XCTFail("Expected an error to be thrown for an invalid URL, but no error was thrown.")
        } catch {
            XCTAssertTrue(error is URLError, "The error should be a URLError.")
        }
    }

    func testFetchURLTaskNonExistentURL() async throws {
        // Given
        let nonExistentURL = URL(string: "https://thisurldoesnotexist.tld")!
        task = FetchURLTask(url: nonExistentURL)

        // When/Then
        do {
            _ = try await task.execute()
            XCTFail("Expected an error to be thrown for a non-existent URL, but no error was thrown.")
        } catch {
            XCTAssertTrue(error is URLError, "The error should be a URLError for a non-existent URL.")
        }
    }

    func testFetchURLTaskWithLargeResponse() async throws {
        // Given
        let largeResponseURL = URL(string: "https://httpbin.org/bytes/10240")! // Generates a 10KB response
        task = FetchURLTask(url: largeResponseURL)

        // When
        let taskOutputs = try await task.execute()

        // Then
        XCTAssertNotNil(taskOutputs["data"], "The data output should not be nil.")
        if let data = taskOutputs["data"] as? Data {
            XCTAssertEqual(data.count, 10240, "The fetched data size should match the expected size (10KB).")
        }
    }

    func testFetchURLTaskTimeout() async throws {
        // Given
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 2 // 2-second timeout
        let timeoutURL = URL(string: "https://httpbin.org/delay/10")! // Delays response by 10 seconds
        let session = URLSession(configuration: config)
        task = FetchURLTask(url: timeoutURL, session: session)

        // When/Then
        do {
            _ = try await task.execute()
            XCTFail("Expected a timeout error to be thrown, but no error was thrown.")
        } catch {
            XCTAssertTrue(error is URLError, "The error should be a URLError for a timeout.")
        }
    }
}
