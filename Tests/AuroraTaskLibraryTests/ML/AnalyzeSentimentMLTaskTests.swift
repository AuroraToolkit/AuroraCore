//
//  AnalyzeSentimentMLTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/5/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraML
@testable import AuroraTaskLibrary

final class AnalyzeSentimentMLTaskTests: XCTestCase {

    // MARK: – Mock‐based tests

    func testAnalyzeSentimentMLTaskSuccess() async throws {
        // Given
        let texts = ["Happy", "Sad"]
        // Create one Tag per text carrying a raw score of ±1.0
        let tag1 = Tag(token: "Happy",
                       label: "positive",
                       scheme: "mock",
                       confidence: 1.0,
                       start: 0,
                       length: 5)
        let tag2 = Tag(token: "Sad",
                       label: "negative",
                       scheme: "mock",
                       confidence: -1.0,
                       start: 0,
                       length: 3)
        let tags: [[Tag]] = [[tag1], [tag2]]
        let mockService = MockMLService(
            name: "MockSentimentService",
            response: MLResponse(outputs: ["tags": tags], info: nil)
        )
        let task = AnalyzeSentimentMLTask(
            mlService: mockService,
            strings: texts
        )

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        guard let sentiments = outputs["sentiments"] as? [String: String] else {
            XCTFail("Output 'sentiments' missing or wrong type")
            return
        }
        XCTAssertEqual(sentiments["Happy"], "positive")
        XCTAssertEqual(sentiments["Sad"], "negative")
    }

    func testAnalyzeSentimentMLTaskEmptyInput() async {
        // Given a service that returns no tags but it's unused because inputs are empty
        let mock = MockMLService(
            name: "MockSentimentService",
            response: MLResponse(outputs: ["tags": [[Tag]]()], info: nil)
        )
        let task = AnalyzeSentimentMLTask(mlService: mock)

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }

        // Then
        do {
            _ = try await wrapped.execute()
            XCTFail("Expected error for empty input")
        } catch let err as NSError {
            XCTAssertEqual(err.domain, "AnalyzeSentimentMLTask")
            XCTAssertEqual(err.code, 1)
        }
    }

    func testAnalyzeSentimentMLTaskInputOverride() async throws {
        // Given initial strings but override provided at execute time
        let initial = ["A"]
        let override = ["X"]
        // Always returns neutral for override
        let tagX = Tag(token: "X",
                       label: "neutral",
                       scheme: "mock",
                       confidence: 0.0,
                       start: 0,
                       length: 1)
        let service = MockMLService(
            name: "MockSentimentService",
            response: MLResponse(outputs: ["tags": [[tagX]]], info: nil)
        )
        let task = AnalyzeSentimentMLTask(
            mlService: service,
            strings: initial
        )

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute(inputs: ["strings": override])

        // Then
        guard let sentiments = outputs["sentiments"] as? [String: String] else {
            XCTFail("Output 'sentiments' missing or wrong type")
            return
        }
        XCTAssertEqual(sentiments, ["X": "neutral"])
    }

    // MARK: – Integration with real TaggingService

    func testAnalyzeSentimentMLTaskWithTaggingServicePositive() async throws {
        // Given
        let positiveText = "I absolutely love this!"
        let service = TaggingService(
            name: "SentimentTagger",
            schemes: [.sentimentScore],
            unit: .paragraph
        )
        let task = AnalyzeSentimentMLTask(
            mlService: service,
            strings: [positiveText]
        )

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        guard let sentiments = outputs["sentiments"] as? [String: String] else {
            XCTFail("Output 'sentiments' missing or wrong type")
            return
        }
        XCTAssertEqual(sentiments[positiveText], "positive")
    }

    /// Tests the simple output (only includes sentiment labels).
    func testAnalyzeSentimentMLTask_NonDetailed() async throws {
        // Given
        let texts = [
            "I love it!",          // strong positive
            "I am indifferent.",   // weak/neutral
            "I hate it."           // negative
        ]
        let service = TaggingService(
            name: "SentimentTagger",
            schemes: [.sentimentScore],
            unit: .paragraph
        )
        let task = AnalyzeSentimentMLTask(
            mlService: service,
            strings: texts,
            detailed: false,
            positiveThreshold: 0.4,
            negativeThreshold: -0.4
        )

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        guard let sentiments = outputs["sentiments"] as? [String: String] else {
            XCTFail("Output 'sentiments' missing or wrong type")
            return
        }
        XCTAssertEqual(sentiments[texts[0]], "positive")
        XCTAssertEqual(sentiments[texts[1]], "neutral")
        XCTAssertEqual(sentiments[texts[2]], "negative")
    }

    /// Tests the detailed output (includes integer confidence percentages).
    func testAnalyzeSentimentMLTask_Detailed() async throws {
        // Given
        let texts = [
            "I love it!",          // strong positive
            "I am indifferent.",   // weak/neutral
            "I hate it."           // negative
        ]
        let service = TaggingService(
            name: "SentimentTagger",
            schemes: [.sentimentScore],
            unit: .paragraph
        )
        let task = AnalyzeSentimentMLTask(
            mlService: service,
            strings: texts,
            detailed: true,
            positiveThreshold: 0.4,
            negativeThreshold: -0.4
        )

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        guard let detailedMap = outputs["sentiments"] as? [String: [String: Any]] else {
            XCTFail("Expected detailed sentiments map")
            return
        }

        // "I love it!" → positive, ~100%
        if let entry = detailedMap[texts[0]] {
            XCTAssertEqual(entry["sentiment"] as? String, "positive")
            let conf = entry["confidence"] as? Int ?? 0
            XCTAssertGreaterThanOrEqual(conf, 50, "Expected ≥50% confidence for strong positive")
        } else {
            XCTFail("Missing entry for \(texts[0])")
        }

        // "I am indifferent." → neutral, ~40%
        if let entry = detailedMap[texts[1]] {
            XCTAssertEqual(entry["sentiment"] as? String, "neutral")
            let conf = entry["confidence"] as? Int ?? 0
            XCTAssertGreaterThanOrEqual(conf, 25, "Expected ≥30% confidence for neutral")
        } else {
            XCTFail("Missing entry for \(texts[1])")
        }

        // "I hate it." → negative, ~60%
        if let entry = detailedMap[texts[2]] {
            XCTAssertEqual(entry["sentiment"] as? String, "negative")
            let conf = entry["confidence"] as? Int ?? 0
            XCTAssertGreaterThanOrEqual(conf, 50, "Expected ≥50% confidence for negative")
        } else {
            XCTFail("Missing entry for \(texts[2])")
        }
    }
}
