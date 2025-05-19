//
//  SentimentTaggingWithTaggingTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/8/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraML
@testable import AuroraTaskLibrary

final class SentimentTaggingWithTaggingTaskTests: XCTestCase {

    func testSentimentTaggingPositive() async throws {
        // Given
        let text = "I absolutely love this product!"
        let service = TaggingService(
            name: "SentimentTagger",
            schemes: [.sentimentScore],
            unit: .paragraph
        )
        let task = TaggingMLTask(service: service, strings: [text])

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        guard let result = outputs["tags"] as? [[Tag]],
              let tags = result.first,
              let scoreString = tags.first?.label,
              let score = Double(scoreString) else {
            XCTFail("Missing or invalid sentiment score tag")
            return
        }
        XCTAssertGreaterThan(score, 0, "Expected positive sentiment (> 0) for: \(text)")
    }

    func testSentimentTaggingNegative() async throws {
        // Given
        let text = "This is the worst experience ever."
        let service = TaggingService(
            name: "SentimentTagger",
            schemes: [.sentimentScore],
            unit: .paragraph
        )
        let task = TaggingMLTask(service: service, strings: [text])

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        guard let result = outputs["tags"] as? [[Tag]],
              let tags = result.first,
              let scoreString = tags.first?.label,
              let score = Double(scoreString) else {
            XCTFail("Missing or invalid sentiment score tag")
            return
        }
        XCTAssertLessThan(score, 0, "Expected negative sentiment (< 0) for: \(text)")
    }
}
