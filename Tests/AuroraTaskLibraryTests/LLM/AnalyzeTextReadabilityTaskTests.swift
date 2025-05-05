//
//  AnalyzeTextReadabilityTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/4/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraLLM
@testable import AuroraTaskLibrary

final class AnalyzeTextReadabilityTaskTests: XCTestCase {

    func testAnalyzeTextReadabilityTaskSuccess() async throws {
        // Given
        let mockResponseText = """
        {
          "readabilityScores": {
            "This is a simple sentence.": {
              "FleschKincaidGradeLevel": 2.3,
              "AverageWordLength": 4.2
            },
            "Using complex syntax and intricate word choice, the author conveyed their ideas.": {
              "FleschKincaidGradeLevel": 12.5,
              "AverageWordLength": 6.8
            }
          }
        }
        """
        let mockService = MockLLMService(
            name: "Mock Readability Analyzer",
            expectedResult: .success(MockLLMResponse(text: mockResponseText))
        )

        let task = AnalyzeTextReadabilityTask(
            llmService: mockService,
            strings: [
                "This is a simple sentence.",
                "Using complex syntax and intricate word choice, the author conveyed their ideas."
            ]
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let outputs = try await unwrappedTask.execute()

        // Then
        guard let readabilityScores = outputs["readabilityScores"] as? [String: [String: Any]] else {
            XCTFail("Output 'readabilityScores' not found or invalid.")
            return
        }

        XCTAssertEqual(
            readabilityScores["This is a simple sentence."]?["FleschKincaidGradeLevel"] as? Double,
            2.3,
            "The Flesch-Kincaid grade level for the first string should match."
        )
        XCTAssertEqual(
            readabilityScores["This is a simple sentence."]?["AverageWordLength"] as? Double,
            4.2,
            "The average word length for the first string should match."
        )
    }

    func testAnalyzeTextReadabilityTaskEmptyInput() async {
        // Given
        let mockService = MockLLMService(
            name: "Mock Readability Analyzer",
            expectedResult: .failure(NSError(domain: "AnalyzeTextReadabilityTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "No strings provided for readability analysis."]))
        )

        let task = AnalyzeTextReadabilityTask(
            llmService: mockService,
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
            XCTAssertEqual((error as NSError).domain, "AnalyzeTextReadabilityTask", "Error domain should match.")
            XCTAssertEqual((error as NSError).code, 1, "Error code should match for empty input.")
        }
    }

    func testAnalyzeTextReadabilityTaskIntegrationWithOllama() async throws {
        // Given
        let stringsToAnalyze = [
            "This is a simple sentence.",
            "Using complex syntax and intricate word choice, the author conveyed their ideas."
        ]

        let ollamaService = OllamaService(name: "OllamaTest")

        let task = AnalyzeTextReadabilityTask(
            llmService: ollamaService,
            strings: stringsToAnalyze
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let outputs = try await unwrappedTask.execute()

        // Then
        guard let readabilityScores = outputs["readabilityScores"] as? [String: [String: Any]] else {
            XCTFail("Output 'readabilityScores' not found or invalid.")
            return
        }

        for string in stringsToAnalyze {
            XCTAssertNotNil(
                readabilityScores[string],
                "Each input string should have a corresponding readability analysis result."
            )
            XCTAssertNotNil(
                readabilityScores[string]?["FleschKincaidGradeLevel"],
                "Each analysis should include a Flesch-Kincaid grade level."
            )
            XCTAssertNotNil(
                readabilityScores[string]?["AverageWordLength"],
                "Each analysis should include an average word length."
            )
        }
    }
}
