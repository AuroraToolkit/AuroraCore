//
//  TokenManagerTests.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/20/24.
//

import XCTest
@testable import AuroraCore

final class TokenManagerTests: XCTestCase {

    var tokenManager: TokenManager!

    override func tearDown() {
        tokenManager = nil
        super.tearDown()
    }

    func testTokenEstimation() {
        // Given
        tokenManager = TokenManager(maxTokenLimit: 100)

        // When
        let text = String(repeating: "A", count: 100)
        let estimatedTokens = tokenManager.estimatedTokenCount(for: text)

        // Then
        XCTAssertEqual(estimatedTokens, 25, "Estimated token count should be roughly 1 token per 4 characters.")
    }

    func testIsWithinTokenLimit() {
        // Given
        tokenManager = TokenManager(maxTokenLimit: 100)

        // When
        let prompt = String(repeating: "A", count: 80) // 20 tokens
        let context = String(repeating: "B", count: 80) // 20 tokens
        let withinLimit = tokenManager.isWithinTokenLimit(prompt: prompt, context: context)

        // Then
        XCTAssertTrue(withinLimit, "Should be within the token limit.")
    }

    func testExceedingTokenLimitWithBuffer() {
        // Given
        tokenManager = TokenManager(maxTokenLimit: 100, buffer: 0.1) // 10% buffer

        // When
        let prompt = String(repeating: "A", count: 400) // 100 tokens
        let context = String(repeating: "B", count: 400) // 100 tokens
        let withinLimit = tokenManager.isWithinTokenLimit(prompt: prompt, context: context)

        // Then
        XCTAssertFalse(withinLimit, "Should exceed the token limit with the buffer.")
    }

    func testTrimmingFromStart() {
        // Given
        tokenManager = TokenManager(maxTokenLimit: 100)

        let prompt = String(repeating: "A", count: 120) // 30 tokens
        let context = String(repeating: "B", count: 400) // 100 tokens

        // When
        let (trimmedPrompt, trimmedContext) = tokenManager.trimToFitTokenLimit(prompt: prompt, context: context, strategy: .start)

        // Then
        XCTAssertEqual(trimmedPrompt.count, 120, "Prompt should not be trimmed.")
        XCTAssertLessThan(trimmedContext?.count ?? 0, 400, "Context should be trimmed from the start.")
    }

    func testTrimmingFromEnd() {
        // Given
        tokenManager = TokenManager(maxTokenLimit: 100)

        let prompt = String(repeating: "A", count: 120) // 30 tokens
        let context = String(repeating: "B", count: 400) // 100 tokens

        // When
        let (trimmedPrompt, trimmedContext) = tokenManager.trimToFitTokenLimit(prompt: prompt, context: context, strategy: .end)

        // Then
        XCTAssertEqual(trimmedPrompt.count, 120, "Prompt should not be trimmed.")
        XCTAssertLessThan(trimmedContext?.count ?? 0, 400, "Context should be trimmed from the end.")
    }

    func testTrimmingFromMiddle() {
        // Given
        tokenManager = TokenManager(maxTokenLimit: 100)

        let prompt = String(repeating: "A", count: 120) // 30 tokens
        let context = String(repeating: "B", count: 400) // 100 tokens

        // When
        let (trimmedPrompt, trimmedContext) = tokenManager.trimToFitTokenLimit(prompt: prompt, context: context, strategy: .middle)

        // Then
        XCTAssertEqual(trimmedPrompt.count, 120, "Prompt should not be trimmed.")
        XCTAssertLessThan(trimmedContext?.count ?? 0, 400, "Context should be trimmed from the middle.")
    }

    func testExactTokenLimitTrimming() {
        // Given
        tokenManager = TokenManager(maxTokenLimit: 100, buffer: 0.05) // 5% buffer

        let prompt = String(repeating: "A", count: 160) // 40 tokens
        let context = String(repeating: "B", count: 240) // 60 tokens

        // When
        let (trimmedPrompt, trimmedContext) = tokenManager.trimToFitTokenLimit(prompt: prompt, context: context)

        // Then
        let adjustedLimit = Int(Double(100) * (1 - 0.05)) // 95 tokens due to the buffer
        let totalTokens = tokenManager.estimatedTokenCount(for: trimmedPrompt) + tokenManager.estimatedTokenCount(for: trimmedContext ?? "")
        XCTAssertEqual(totalTokens, adjustedLimit, "Trimmed content should fit within the adjusted token limit.")
    }

    func testBufferedTrimming() {
        // Given
        tokenManager = TokenManager(maxTokenLimit: 100, buffer: 0.1) // 10% buffer

        let prompt = String(repeating: "A", count: 200) // 50 tokens
        let context = String(repeating: "B", count: 200) // 50 tokens

        // When
        let (trimmedPrompt, trimmedContext) = tokenManager.trimToFitTokenLimit(prompt: prompt, context: context)

        // Then
        let totalTokens = tokenManager.estimatedTokenCount(for: trimmedPrompt) + tokenManager.estimatedTokenCount(for: trimmedContext ?? "")
        XCTAssertEqual(totalTokens, 90, "Trimmed content should fit within the adjusted token limit with the buffer.")
    }

    func testTrimToFitTokenLimit_startStrategy_trimPromptWhenContextIsEmpty() {
        // Given
        let manager = TokenManager(maxTokenLimit: 10) // Small token limit to trigger trimming quickly
        let prompt = "This is a very long prompt that will exceed the limit."
        let context: String? = ""

        // When
        let (trimmedPrompt, trimmedContext) = manager.trimToFitTokenLimit(prompt: prompt, context: context, strategy: .start)

        // Then
        XCTAssertTrue(trimmedPrompt.hasSuffix("will exceed the limit."), "Prompt should be trimmed from the start.")
        XCTAssertEqual(trimmedContext, "", "Context should remain empty.")
    }

    func testTrimToFitTokenLimit_middleStrategy_trimPromptWhenContextIsEmpty() {
        // Given
        let manager = TokenManager(maxTokenLimit: 12) // Small token limit to trigger trimming
        let prompt = "This is a very long prompt that will exceed the limit."
        let context: String? = ""

        // When
        let (trimmedPrompt, trimmedContext) = manager.trimToFitTokenLimit(prompt: prompt, context: context, strategy: .middle)

        // Then
        let totalToTrim = 10 // We are trimming 10 characters in total
        let halfTrim = totalToTrim / 2

        let middleIndex = prompt.index(prompt.startIndex, offsetBy: prompt.count / 2)
        let firstHalfEndIndex = prompt.index(middleIndex, offsetBy: -halfTrim)
        let secondHalfStartIndex = prompt.index(middleIndex, offsetBy: halfTrim)

        let expectedTrimmed = String(prompt[..<firstHalfEndIndex]) + String(prompt[secondHalfStartIndex...])

        XCTAssertEqual(trimmedPrompt, expectedTrimmed, "Prompt should be trimmed equally from the middle.")
        XCTAssertEqual(trimmedContext, "", "Context should remain empty.")
    }
}
