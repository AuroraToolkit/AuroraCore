//
//  StringExtensionsTests.swift
//
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import XCTest
@testable import AuroraCore

final class StringExtensionsTests: XCTestCase {

    func testEstimatedTokenCount() {
        // Given
        let input = "This is a test string."

        // When
        let tokenCount = input.estimatedTokenCount()

        // Then
        XCTAssertEqual(tokenCount, 5, "Estimated token count should be 5.")
    }

    func testTrimmedToFitWithStartStrategy() {
        // Given
        let input = String(repeating: "A", count: 200) // 200 characters, 50 tokens
        let tokenLimit = 30
        let buffer = 0.05
        let adjustedLimit = Int(floor(Double(tokenLimit) * (1 - buffer)))
        let lowerBound = adjustedLimit - 2
        let upperBound = adjustedLimit + 2

        // When
        let trimmedString = input.trimmedToFit(tokenLimit: tokenLimit, buffer: buffer, strategy: .start)
        let tokenCount = trimmedString.estimatedTokenCount()

        // Then
        XCTAssertTrue((lowerBound...upperBound).contains(tokenCount), "Trimmed string should have between \(lowerBound) and \(upperBound) tokens, but has \(tokenCount).")
    }

    func testTrimmedToFitWithMiddleStrategy() {
        // Given
        let input = String(repeating: "A", count: 200) // 200 characters, 50 tokens
        let tokenLimit = 30
        let buffer = 0.05
        let adjustedLimit = Int(floor(Double(tokenLimit) * (1 - buffer)))
        let lowerBound = adjustedLimit - 2
        let upperBound = adjustedLimit + 2

        // When
        let trimmedString = input.trimmedToFit(tokenLimit: tokenLimit, buffer: buffer, strategy: .middle)
        let tokenCount = trimmedString.estimatedTokenCount()

        // Then
        XCTAssertTrue((lowerBound...upperBound).contains(tokenCount), "Trimmed string should have between \(lowerBound) and \(upperBound) tokens, but has \(tokenCount).")
    }

    func testTrimmedToFitWithEndStrategy() {
        // Given
        let input = String(repeating: "A", count: 200) // 200 characters, 50 tokens
        let tokenLimit = 30
        let buffer = 0.05
        let adjustedLimit = Int(floor(Double(tokenLimit) * (1 - buffer)))
        let lowerBound = adjustedLimit - 2
        let upperBound = adjustedLimit + 2

        // When
        let trimmedString = input.trimmedToFit(tokenLimit: tokenLimit, buffer: buffer, strategy: .end)
        let tokenCount = trimmedString.estimatedTokenCount()

        // Then
        XCTAssertTrue((lowerBound...upperBound).contains(tokenCount), "Trimmed string should have between \(lowerBound) and \(upperBound) tokens, but has \(tokenCount).")
    }

    func testIsWithinTokenLimitWithContext() {
        // Given
        let prompt = "This is a test string."
        let context = "Additional context to check token limits."
        let tokenLimit = 20
        let buffer = 0.1 // 10% buffer
        let adjustedLimit = Int(floor(Double(tokenLimit) * (1 - buffer)))

        // When
        let result = prompt.isWithinTokenLimit(context: context, tokenLimit: tokenLimit, buffer: buffer)

        // Then
        let combinedTokenCount = (prompt + context).estimatedTokenCount()
        XCTAssertEqual(combinedTokenCount <= adjustedLimit, result, "The token count check should match the result of isWithinTokenLimit.")
    }

    func testIsWithinTokenLimitWithoutContext() {
        // Given
        let prompt = "Short string."
        let tokenLimit = 10
        let buffer = 0.2 // 20% buffer
        let adjustedLimit = Int(floor(Double(tokenLimit) * (1 - buffer)))

        // When
        let result = prompt.isWithinTokenLimit(tokenLimit: tokenLimit, buffer: buffer)

        // Then
        let combinedTokenCount = prompt.estimatedTokenCount()
        XCTAssertEqual(combinedTokenCount <= adjustedLimit, result, "The token count check should match the result of isWithinTokenLimit.")
    }

    func testIsWithinTokenLimitExactlyAtLimit() {
        // Given
        let prompt = String(repeating: "A", count: 40) // 40 characters, ~10 tokens
        let context = String(repeating: "B", count: 40) // 40 characters, ~10 tokens
        let tokenLimit = 20
        let buffer = 0.0 // No buffer
        let adjustedLimit = Int(floor(Double(tokenLimit) * (1 - buffer)))

        // When
        let result = prompt.isWithinTokenLimit(context: context, tokenLimit: tokenLimit, buffer: buffer)

        // Then
        let combinedTokenCount = (prompt + context).estimatedTokenCount()
        XCTAssertEqual(combinedTokenCount, adjustedLimit, "Combined token count should exactly match the adjusted limit.")
        XCTAssertTrue(result, "The result should be true when combined token count matches the limit exactly.")
    }

    func testIsWithinTokenLimitExceedingLimit() {
        // Given
        let prompt = String(repeating: "A", count: 50) // 50 characters, ~12 tokens
        let context = String(repeating: "B", count: 50) // 50 characters, ~12 tokens
        let tokenLimit = 20
        let buffer = 0.05 // 5% buffer
        let adjustedLimit = Int(floor(Double(tokenLimit) * (1 - buffer)))

        // When
        let result = prompt.isWithinTokenLimit(context: context, tokenLimit: tokenLimit, buffer: buffer)

        // Then
        let combinedTokenCount = (prompt + context).estimatedTokenCount()
        XCTAssertTrue(combinedTokenCount > adjustedLimit, "Combined token count should exceed the adjusted limit.")
        XCTAssertFalse(result, "The result should be false when combined token count exceeds the limit.")
    }

    func testIsWithinTokenLimitWithEmptyStrings() {
        // Given
        let prompt = ""
        let context = ""
        let tokenLimit = 20
        let buffer = 0.05 // 5% buffer

        // When
        let result = prompt.isWithinTokenLimit(context: context, tokenLimit: tokenLimit, buffer: buffer)

        // Then
        XCTAssertTrue(result, "The result should be true when both the prompt and context are empty.")
    }

    func testIsWithinTokenLimitWithNilContext() {
        // Given
        let prompt = "This is a test string."
        let tokenLimit = 10
        let buffer = 0.1 // 10% buffer
        let adjustedLimit = Int(floor(Double(tokenLimit) * (1 - buffer)))

        // When
        let result = prompt.isWithinTokenLimit(context: nil, tokenLimit: tokenLimit, buffer: buffer)

        // Then
        let combinedTokenCount = prompt.estimatedTokenCount()
        XCTAssertEqual(combinedTokenCount <= adjustedLimit, result, "The token count check should match the result of isWithinTokenLimit.")
    }
}
