//
//  AnalyzeSentimentTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/2/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraLLM
@testable import AuroraTaskLibrary

final class AnalyzeSentimentTaskTests: XCTestCase {

    func testAnalyzeSentimentTaskSuccess() async throws {
        // Given
        let stringsToAnalyze = ["I love this!", "It’s okay.", "I’m very disappointed."]
        let mockResponseText = """
        {
          "sentiments": {
            "I love this!": "Positive",
            "It’s okay.": "Neutral",
            "I’m very disappointed.": "Negative"
          }
        }
        """
        let mockService = MockLLMService(
            name: "MockService",
            expectedResult: .success(MockLLMResponse(text: mockResponseText))
        )

        let task = AnalyzeSentimentTask(
            llmService: mockService,
            strings: stringsToAnalyze
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await unwrappedTask.execute()

        // Then
        guard let sentiments = outputs["sentiments"] as? [String: String] else {
            XCTFail("Output 'sentiments' not found or invalid.")
            return
        }
        XCTAssertEqual(sentiments["I love this!"], "Positive")
        XCTAssertEqual(sentiments["It’s okay."], "Neutral")
        XCTAssertEqual(sentiments["I’m very disappointed."], "Negative")
    }

    func testAnalyzeSentimentTaskEmptyInput() async {
        // Given
        let mockService = MockLLMService(
            name: "MockService",
            expectedResult: .success(MockLLMResponse(text: "{}"))
        )
        let task = AnalyzeSentimentTask(
            llmService: mockService,
            strings: []
        )

        // When/Then
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap Workflow.Task.")
                return
            }
            _ = try await unwrappedTask.execute()
            XCTFail("Expected an error to be thrown for empty input, but no error was thrown.")
        } catch {
            XCTAssertEqual((error as NSError).domain, "AnalyzeSentimentTask", "Error domain should match.")
            XCTAssertEqual((error as NSError).code, 1, "Error code should match for empty input.")
        }
    }

    func testAnalyzeSentimentTaskIntegrationWithOllama() async throws {
        // Given
        let stringsToAnalyze = ["This is fantastic!", "Not bad, could be better.", "I hate this."]
        let ollamaService = OllamaService(name: "OllamaTest")

        let task = AnalyzeSentimentTask(
            llmService: ollamaService,
            strings: stringsToAnalyze
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await unwrappedTask.execute()

        // Then
        guard let sentiments = outputs["sentiments"] as? [String: String] else {
            XCTFail("Output 'sentiments' not found or invalid.")
            return
        }

        XCTAssertEqual(sentiments["This is fantastic!"], "Positive")
        XCTAssertEqual(sentiments["Not bad, could be better."], "Neutral")
        XCTAssertEqual(sentiments["I hate this."], "Negative")
    }

    func testAnalyzeSentimentTaskExpectedSentimentsWithOllama() async throws {
        // Given
        let stringsToAnalyze = ["I love this!", "It’s okay.", "I’m very disappointed."]
        let expectedSentiments = [
            "I love this!": "Positive",
            "It’s okay.": "Neutral",
            "I’m very disappointed.": "Negative"
        ]

        let ollamaService = OllamaService(name: "OllamaTest")

        let task = AnalyzeSentimentTask(
            llmService: ollamaService,
            strings: stringsToAnalyze
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await unwrappedTask.execute()

        // Then
        guard let sentiments = outputs["sentiments"] as? [String: String] else {
            XCTFail("Output 'sentiments' not found or invalid.")
            return
        }

        // Compare the expected sentiments
        for (string, sentiment) in expectedSentiments {
            XCTAssertEqual(sentiments[string], sentiment, "Sentiment for '\(string)' does not match expected value.")
        }

        print("Integration test results: \(sentiments)")
    }

    func testAnalyzeSentimentTaskDetailedMock() async throws {
        // Given
        let stringsToAnalyze = ["I love this!", "It’s okay.", "I’m very disappointed."]
        let expectedSentiments = [
            "I love this!": ["sentiment": "Positive", "confidence": 95],
            "It’s okay.": ["sentiment": "Neutral", "confidence": 70],
            "I’m very disappointed.": ["sentiment": "Negative", "confidence": 90]
        ]

        let mockResponseText = """
        {
          "sentiments": {
            "I love this!": {"sentiment": "Positive", "confidence": 95},
            "It’s okay.": {"sentiment": "Neutral", "confidence": 70},
            "I’m very disappointed.": {"sentiment": "Negative", "confidence": 90}
          }
        }
        """
        let mockService = MockLLMService(
            name: "MockService",
            expectedResult: .success(MockLLMResponse(text: mockResponseText))
        )

        let task = AnalyzeSentimentTask(
            llmService: mockService,
            strings: stringsToAnalyze,
            detailed: true
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await unwrappedTask.execute()

        // Then
        guard let detailedSentiments = outputs["sentiments"] as? [String: [String: Any]] else {
            XCTFail("Output 'sentiments' not found or invalid.")
            return
        }
        XCTAssertEqual(detailedSentiments.count, expectedSentiments.count, "Sentiment counts should match.")
        for (key, value) in expectedSentiments {
            XCTAssertEqual(detailedSentiments[key]?["sentiment"] as? String, value["sentiment"] as? String, "Sentiment for \(key) should match.")
            XCTAssertEqual(detailedSentiments[key]?["confidence"] as? Int, value["confidence"] as? Int, "Confidence for \(key) should match.")
        }
    }

    func testAnalyzeSentimentTaskDetailedIntegrationWithOllama() async throws {
        // Given
        let stringsToAnalyze = ["I love this!", "It’s okay.", "I’m very disappointed."]
        let ollamaService = OllamaService(name: "OllamaTest")

        let task = AnalyzeSentimentTask(
            llmService: ollamaService,
            strings: stringsToAnalyze,
            detailed: true
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await unwrappedTask.execute()

        // Then
        guard let detailedSentiments = outputs["sentiments"] as? [String: [String: Any]] else {
            XCTFail("Output 'sentiments' not found or invalid.")
            return
        }

        XCTAssertEqual(detailedSentiments.count, stringsToAnalyze.count, "Sentiment counts should match the number of input strings.")
        detailedSentiments.forEach { (string, sentimentDetails) in
            XCTAssertNotNil(sentimentDetails["sentiment"] as? String, "Sentiment for \(string) should not be nil.")
            XCTAssertNotNil(sentimentDetails["confidence"] as? Int, "Confidence for \(string) should not be nil.")
        }
    }
}
