//
//  ExtractRelationsTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/4/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraLLM
@testable import AuroraTaskLibrary

final class ExtractRelationsTaskTests: XCTestCase {

    func testExtractRelationsTaskSuccess() async throws {
        // Given
        let mockResponseText = """
    {
      "relations": {
        "co_founded": [["Steve Jobs", "Apple"], ["Steve Wozniak", "Apple"]],
        "located_in": [["Apple", "Cupertino, California"]]
      }
    }
    """
        let mockService = MockLLMService(
            name: "Mock Relation Extractor",
            expectedResult: .success(MockLLMResponse(text: mockResponseText))
        )

        let task = ExtractRelationsTask(
            llmService: mockService,
            strings: [
                "Steve Jobs was the co-founder of Apple, headquartered in Cupertino, California.",
                "Steve Wozniak co-founded Apple with Steve Jobs."
            ],
            relationTypes: ["co_founded", "located_in"]
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let outputs = try await unwrappedTask.execute()

        // Then
        guard let relations = outputs["relations"] as? [String: [[String]]] else {
            XCTFail("Output 'relations' not found or invalid.")
            return
        }

        XCTAssertEqual(relations["co_founded"]?.count, 2, "Expected 2 co-founded relations.")
        XCTAssertEqual(relations["located_in"]?.count, 1, "Expected 1 located_in relation.")
    }

    func testExtractRelationsTaskEmptyInput() async {
        // Given
        let mockService = MockLLMService(
            name: "Mock Relation Extractor",
            expectedResult: .failure(NSError(domain: "ExtractRelationsTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "No strings provided for extraction."]))
        )

        let task = ExtractRelationsTask(
            llmService: mockService,
            strings: [],
            relationTypes: ["co_founded", "located_in"]
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
            XCTAssertEqual((error as NSError).domain, "ExtractRelationsTask", "Error domain should match.")
            XCTAssertEqual((error as NSError).code, 1, "Error code should match for empty input.")
        }
    }

    func testExtractRelationsTaskIntegrationWithOllama() async throws {
        // Given
        let stringsToExtractFrom = [
            "Steve Jobs was the co-founder of Apple, headquartered in Cupertino, California.",
            "Steve Wozniak co-founded Apple with Steve Jobs."
        ]
        let ollamaService = OllamaService(name: "OllamaTest")

        let task = ExtractRelationsTask(
            llmService: ollamaService,
            strings: stringsToExtractFrom,
            relationTypes: ["co_founded", "located_in"]
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let outputs = try await unwrappedTask.execute()

        // Then
        guard let relations = outputs["relations"] as? [String: [[String]]] else {
            XCTFail("Output 'relations' not found or invalid.")
            return
        }

        XCTAssertNotNil(relations["co_founded"], "Expected co_founded relations to be extracted.")
        XCTAssertNotNil(relations["located_in"], "Expected located_in relations to be extracted.")
        XCTAssertTrue(!relations["co_founded"]!.isEmpty, "Expected co-founded relations.")
        XCTAssertTrue(!relations["located_in"]!.isEmpty, "Expected located_in relation.")
    }
}
