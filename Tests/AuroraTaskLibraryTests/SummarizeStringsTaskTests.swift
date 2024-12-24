//
//  SummarizeStringsTaskTests.swift
//  AuroraCoreTests
//
//  Created by Dan Murrell Jr on 12/10/24.
//

import XCTest
@testable import AuroraCore
@testable import AuroraLLM
@testable import AuroraTaskLibrary

final class SummarizeStringsTaskTests: XCTestCase {

    func testSummarizeStringsTaskSingleTypeSuccess() async throws {
        // Given
        let stringsToSummarize = ["This is a test string."]
        let expectedSummaries = ["Summary of: This is a test string."]
        let mockSummarizer = MockSummarizer(expectedSummaries: expectedSummaries)

        let task = SummarizeStringsTask(
            summarizer: mockSummarizer,
            summaryType: .single,
            strings: stringsToSummarize
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let outputs = try await unwrappedTask.execute()

        // Then
        guard let summaries = outputs["summaries"] as? [String] else {
            XCTFail("Output 'summaries' not found or invalid")
            return
        }
        XCTAssertEqual(summaries.count, stringsToSummarize.count, "The number of summaries should match the number of input strings.")
        XCTAssertEqual(summaries, expectedSummaries, "Summaries should match the expected output.")
    }

    func testSummarizeStringsTaskMultipleTypeSuccess() async throws {
        // Given
        let stringsToSummarize = ["This is the first test string.", "This is the second test string."]
        let expectedSummaries = ["Summary of: This is the first test string.", "Summary of: This is the second test string."]
        let mockSummarizer = MockSummarizer(expectedSummaries: expectedSummaries)

        let task = SummarizeStringsTask(
            summarizer: mockSummarizer,
            summaryType: .multiple,
            strings: stringsToSummarize
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let outputs = try await unwrappedTask.execute()

        // Then
        guard let summaries = outputs["summaries"] as? [String] else {
            XCTFail("Output 'summaries' not found or invalid")
            return
        }
        XCTAssertEqual(summaries.count, stringsToSummarize.count, "The number of summaries should match the number of input strings.")
        XCTAssertEqual(summaries, expectedSummaries, "Summaries should match the expected output.")
    }

    func testSummarizeStringsTaskEmptyInput() async {
        // Given
        let mockSummarizer = MockSummarizer(expectedSummaries: [])
        let task = SummarizeStringsTask(
            summarizer: mockSummarizer,
            summaryType: .single,
            strings: []
        )

        // When/Then
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap the Workflow.Task from the component.")
                return
            }

            _ = try await unwrappedTask.execute()
            XCTFail("Expected an error to be thrown for empty input, but no error was thrown.")
        } catch {
            XCTAssertEqual((error as NSError).domain, "SummarizeStringsTask", "Error domain should match.")
            XCTAssertEqual((error as NSError).code, 1, "Error code should match for missing input strings.")
        }
    }

    func testSummarizeStringsTaskSummarizerFailure() async {
        // Given
        let stringsToSummarize = ["This is a test string."]
        let expectedError = NSError(domain: "MockSummarizer", code: 42, userInfo: [NSLocalizedDescriptionKey: "Simulated summarizer error"])
        let mockSummarizer = MockSummarizer(expectedResult: .failure(expectedError))

        let task = SummarizeStringsTask(
            summarizer: mockSummarizer,
            summaryType: .single,
            strings: stringsToSummarize
        )

        // When/Then
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap the Workflow.Task from the component.")
                return
            }

            _ = try await unwrappedTask.execute()
            XCTFail("Expected an error to be thrown by the summarizer, but no error was thrown.")
        } catch {
            XCTAssertEqual((error as NSError).domain, expectedError.domain, "Error domain should match the simulated error.")
            XCTAssertEqual((error as NSError).code, expectedError.code, "Error code should match the simulated error.")
        }
    }

    func testSummarizeStringsTaskInvalidInputs() async {
        // Given
        let mockSummarizer = MockSummarizer(expectedSummaries: [])
        let task = SummarizeStringsTask(
            summarizer: mockSummarizer,
            summaryType: .single,
            strings: [] // Will be replaced with invalid inputs
        )

        // When/Then
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap the Workflow.Task from the component.")
                return
            }

            _ = try await unwrappedTask.execute(inputs: ["strings": "Not an array"])
            XCTFail("Expected an error to be thrown for invalid input, but no error was thrown.")
        } catch {
            XCTAssertEqual((error as NSError).domain, "SummarizeStringsTask", "Error domain should match.")
            XCTAssertEqual((error as NSError).code, 1, "Error code should match for invalid input.")
        }
    }
}
