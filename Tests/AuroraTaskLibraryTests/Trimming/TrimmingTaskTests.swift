//
//  TrimmingTaskTests.swift
//
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import XCTest
@testable import AuroraCore
@testable import AuroraTaskLibrary

final class TrimmingTaskTests: XCTestCase {

    func testTrimmingTaskWithDefaultValues() async throws {
        // Given
        let input = String(repeating: "A", count: 4096) // 4096 characters, ~1024 tokens
        let tokenLimit = 1024
        let buffer = 0.05
        let adjustedLimit = Int(floor(Double(tokenLimit) * (1 - buffer)))
        let lowerBound = adjustedLimit - 2
        let upperBound = adjustedLimit + 2

        let task = TrimmingTask(string: input)

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let taskOutputs = try await unwrappedTask.execute()
        let trimmedString = taskOutputs["trimmedStrings"] as? [String]
        let tokenCount = trimmedString?.first?.estimatedTokenCount()

        // Then
        XCTAssertTrue((lowerBound...upperBound).contains(tokenCount!), "Trimmed string should have between \(lowerBound) and \(upperBound) tokens, but has \(tokenCount!).")
    }

    func testTrimmingTaskWithCustomValues() async throws {
        // Given
        let input = String(repeating: "B", count: 2048) // 2048 characters, ~512 tokens
        let tokenLimit = 256
        let buffer = 0.05
        let adjustedLimit = Int(floor(Double(tokenLimit) * (1 - buffer)))
        let lowerBound = adjustedLimit - 2
        let upperBound = adjustedLimit + 2

        let task = TrimmingTask(
            string: input,
            tokenLimit: tokenLimit,
            strategy: .start
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let taskOutputs = try await unwrappedTask.execute()
        let trimmedString = taskOutputs["trimmedStrings"] as? [String]
        let tokenCount = trimmedString?.first?.estimatedTokenCount()

        // Then
        XCTAssertTrue((lowerBound...upperBound).contains(tokenCount!), "Trimmed string should have between \(lowerBound) and \(upperBound) tokens, but has \(tokenCount!).")
    }

    func testTrimmingTaskWithEndStrategy() async throws {
        // Given
        let input = String(repeating: "C", count: 2048) // 2048 characters, ~512 tokens
        let tokenLimit = 128
        let buffer = 0.05
        let adjustedLimit = Int(floor(Double(tokenLimit) * (1 - buffer)))
        let lowerBound = adjustedLimit - 2
        let upperBound = adjustedLimit + 2

        let task = TrimmingTask(
            string: input,
            tokenLimit: tokenLimit,
            strategy: .end
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let taskOutputs = try await unwrappedTask.execute()
        let trimmedString = taskOutputs["trimmedStrings"] as? [String]
        let tokenCount = trimmedString?.first?.estimatedTokenCount()

        // Then
        XCTAssertTrue((lowerBound...upperBound).contains(tokenCount!), "Trimmed string should have between \(lowerBound) and \(upperBound) tokens, but has \(tokenCount!).")
    }

    func testTrimmingTaskWithMultipleStrings() async throws {
        // Given
        let inputs = [
            String(repeating: "X", count: 4096 * 5),  // Very long string, ~1024 tokens * 5
            String(repeating: "Y", count: 512)        // Short string, ~128 tokens
        ]
        let tokenLimit = 1024
        let buffer = 0.05
        let adjustedLimit = Int(floor(Double(tokenLimit) * (1 - buffer)))
        let lowerBound = adjustedLimit - 2
        let upperBound = adjustedLimit + 2

        let task = TrimmingTask(strings: inputs)

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let taskOutputs = try await unwrappedTask.execute()
        let trimmedStrings = taskOutputs["trimmedStrings"] as? [String]

        // Then
        XCTAssertEqual(trimmedStrings?.count, 2, "Expected two trimmed strings in the output.")
        XCTAssertEqual(trimmedStrings?.last, inputs[1], "The shorter string should not be modified.")

        if let firstTrimmedString = trimmedStrings?.first {
            let tokenCount = firstTrimmedString.estimatedTokenCount()
            XCTAssertTrue((lowerBound...upperBound).contains(tokenCount), "Trimmed string should have between \(lowerBound) and \(upperBound) tokens, but has \(tokenCount).")
        } else {
            XCTFail("First trimmed string is missing in the output.")
        }
    }

    func testTrimmingTaskFailsWithoutRequiredInputs() async {
        // Given
        let task = TrimmingTask(strings: [])

        // When
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap the Workflow.Task from the component.")
                return
            }

            _ = try await unwrappedTask.execute()
            XCTFail("Task should have thrown an error due to missing inputs.")
        } catch {
            // Then
            XCTAssertEqual((error as NSError).domain, "TrimmingTask", "Expected error from TrimmingTask domain.")
        }
    }
}
