//
//  TrimmingTaskTests.swift
//  
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import XCTest
@testable import AuroraCore

final class TrimmingTaskTests: XCTestCase {

    func testTrimmingTaskWithDefaultValues() async throws {
        // Given
        let input = String(repeating: "A", count: 4096) // 4096 characters, ~1024 tokens
        let tokenLimit = 1024
        let buffer = 0.05
        let adjustedLimit = Int(floor(Double(tokenLimit) * (1 - buffer)))
        let lowerBound = adjustedLimit - 2
        let upperBound = adjustedLimit + 2

        let task = TrimmingTask(
            name: "Trim Default",
            description: "Trim input using default values",
            input: input
        )

        // When
        try await task.execute()
        let tokenCount = task.output?.estimatedTokenCount()

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
            name: "Trim Custom",
            description: "Trim input using custom values",
            input: input,
            tokenLimit: tokenLimit,
            strategy: .start
        )

        // When
        try await task.execute()
        let tokenCount = task.output?.estimatedTokenCount()

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
            name: "Trim End Strategy",
            description: "Trim input using end strategy",
            input: input,
            tokenLimit: tokenLimit,
            strategy: .end
        )

        // When
        try await task.execute()
        let tokenCount = task.output?.estimatedTokenCount()

        // Then
        XCTAssertTrue((lowerBound...upperBound).contains(tokenCount!), "Trimmed string should have between \(lowerBound) and \(upperBound) tokens, but has \(tokenCount!).")
    }

    func testTrimmingTaskFailsWithoutRequiredInputs() async {
        // Given
        let task = TrimmingTask(
            name: "Trim Missing Inputs",
            description: "Trim input without required inputs",
            inputs: [:]
        )

        // When
        do {
            try await task.execute()
            XCTFail("Task should have thrown an error due to missing inputs.")
        } catch {
            // Then
            XCTAssertEqual((error as NSError).domain, "TrimmingTask", "Expected error from TrimmingTask domain.")
        }
    }
}
