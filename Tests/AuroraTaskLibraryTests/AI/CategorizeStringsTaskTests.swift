//
//  CategorizeStringsTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/1/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraLLM
@testable import AuroraTaskLibrary

final class CategorizeStringsTaskTests: XCTestCase {

    func testCategorizeStringsTaskSuccess() async throws {
        // Given
        let stringsToCategorize = ["Apple is a tech company.", "The sun is a star."]
        let expectedCategories: [String: [String]] = [
            "Technology": ["Apple is a tech company."],
            "Astronomy": ["The sun is a star."]
        ]
        let mockResponseText = """
        {
          "categories": {
            "Technology": ["Apple is a tech company."],
            "Astronomy": ["The sun is a star."]
          }
        }
        """
        let mockService = MockLLMService(
            name: "MockService",
            expectedResult: .success(MockLLMResponse(text: mockResponseText))
        )

        let task = CategorizeStringsTask(
            llmService: mockService,
            strings: stringsToCategorize,
            categories: ["Technology", "Astronomy", "Biology"]
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await unwrappedTask.execute()

        // Then
        guard let categorizedStrings = outputs["categorizedStrings"] as? [String: [String]] else {
            XCTFail("Output 'categorizedStrings' not found or invalid.")
            return
        }
        XCTAssertEqual(categorizedStrings, expectedCategories, "The categories should match the expected output.")
    }

    func testCategorizeStringsTaskEmptyInput() async {
        // Given
        let mockService = MockLLMService(
            name: "MockService",
            expectedResult: .success(MockLLMResponse(text: "{}"))
        )
        let task = CategorizeStringsTask(
            llmService: mockService,
            strings: [],
            categories: ["Technology", "Astronomy", "Biology"]
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
            XCTAssertEqual((error as NSError).domain, "CategorizeStringsTask", "Error domain should match.")
            XCTAssertEqual((error as NSError).code, 1, "Error code should match for empty input.")
        }
    }

    func testCategorizeStringsTaskInvalidLLMResponse() async {
        // Given
        let stringsToCategorize = ["This is a test string."]
        let mockResponseText = "Invalid JSON"
        let mockService = MockLLMService(
            name: "MockService",
            expectedResult: .success(MockLLMResponse(text: mockResponseText))
        )

        let task = CategorizeStringsTask(
            llmService: mockService,
            strings: stringsToCategorize,
            categories: ["CategoryA", "CategoryB"]
        )

        // When/Then
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap Workflow.Task.")
                return
            }
            _ = try await unwrappedTask.execute()
            XCTFail("Expected an error to be thrown for invalid LLM response, but no error was thrown.")
        } catch {
            XCTAssertEqual((error as NSError).domain, "CategorizeStringsTask", "Error domain should match.")
            XCTAssertEqual((error as NSError).code, 2, "Error code should match for invalid LLM response.")
        }
    }

    func testCategorizeStringsTaskIntegrationWithOllama() async throws {
        // Given
        let stringsToCategorize = ["Water is essential for life.", "E=mc^2 is a famous equation."]
        let categories = ["Science", "Mathematics", "Philosophy"]

        let ollamaService = OllamaService(name: "OllamaTest")

        let task = CategorizeStringsTask(
            llmService: ollamaService,
            strings: stringsToCategorize,
            categories: categories
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await unwrappedTask.execute()

        // Then
        guard let categorizedStrings = outputs["categorizedStrings"] as? [String: [String]] else {
            XCTFail("Output 'categorizedStrings' not found or invalid.")
            return
        }

        XCTAssertFalse(categorizedStrings.isEmpty, "Results should not be empty.")
        print("Integration test results: \(categorizedStrings)")
    }

    func testCategorizeStringsTaskExpectedCategoriesWithOllama() async throws {
        // Given
        let stringsToCategorize = [
            "Water is essential for life.",
            "E=mc^2 is a famous equation."
        ]
        let expectedCategories: [String: [String]] = [
            "Science": ["Water is essential for life."],
            "Mathematics": ["E=mc^2 is a famous equation."]
        ]

        let ollamaService = OllamaService(name: "OllamaTest")

        let task = CategorizeStringsTask(
            llmService: ollamaService,
            strings: stringsToCategorize,
            categories: Array(expectedCategories.keys)
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await unwrappedTask.execute()

        // Then
        guard let categorizedStrings = outputs["categorizedStrings"] as? [String: [String]] else {
            XCTFail("Output 'categorizedStrings' not found or invalid.")
            return
        }

        XCTAssertEqual(categorizedStrings, expectedCategories, "The output categories should match the expected categories.")
    }

    func testCategorizeStringsTaskHandlesEmptyCategories() async {
        // Given
        let stringsToCategorize = ["This is a test string."]
        let mockService = MockLLMService(
            name: "MockService",
            expectedResult: .success(MockLLMResponse(text: "{}"))
        )

        let task = CategorizeStringsTask(
            llmService: mockService,
            strings: stringsToCategorize,
            categories: []
        )

        // When/Then
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap Workflow.Task.")
                return
            }
            _ = try await unwrappedTask.execute()
            XCTFail("Expected an error to be thrown for empty categories, but no error was thrown.")
        } catch {
            XCTAssertEqual((error as NSError).domain, "CategorizeStringsTask", "Error domain should match.")
            XCTAssertEqual((error as NSError).code, 2, "Error code should match for empty categories.")
        }
    }
}
