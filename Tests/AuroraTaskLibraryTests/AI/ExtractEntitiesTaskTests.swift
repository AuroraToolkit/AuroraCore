//
//  ExtractEntitiesTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/3/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraLLM
@testable import AuroraTaskLibrary

final class ExtractEntitiesTaskTests: XCTestCase {

    func testExtractEntitiesTaskSuccess() async throws {
        // Given
        let mockResponseText = """
        {
          "entities": {
            "Person": ["Sam Altman"],
            "Organization": ["OpenAI"],
            "Location": ["San Francisco"]
          }
        }
        """
        let mockService = MockLLMService(
            name: "Mock Entity Extractor",
            expectedResult: .success(MockLLMResponse(text: mockResponseText))
        )

        let task = ExtractEntitiesTask(
            llmService: mockService,
            strings: ["Sam Altman works at OpenAI in San Francisco."],
            entityTypes: ["Person", "Organization", "Location"]
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let outputs = try await unwrappedTask.execute()

        // Then
        guard let entities = outputs["entities"] as? [String: [String]] else {
            XCTFail("Output 'entities' not found or invalid")
            return
        }

        XCTAssertEqual(entities["Person"], ["Sam Altman"], "Extracted persons should match.")
        XCTAssertEqual(entities["Organization"], ["OpenAI"], "Extracted organizations should match.")
        XCTAssertEqual(entities["Location"], ["San Francisco"], "Extracted locations should match.")
    }

    func testExtractEntitiesTaskEmptyInput() async {
        // Given
        let mockService = MockLLMService(
            name: "Mock Entity Extractor",
            expectedResult: .failure(NSError(domain: "ExtractEntitiesTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "No strings provided for extraction."]))
        )

        let task = ExtractEntitiesTask(
            llmService: mockService,
            strings: [],
            entityTypes: ["Person", "Organization"]
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
            XCTAssertEqual((error as NSError).domain, "ExtractEntitiesTask", "Error domain should match.")
            XCTAssertEqual((error as NSError).code, 1, "Error code should match for empty input.")
        }
    }

    func testExtractEntitiesTaskInvalidLLMResponse() async {
        // Given
        let mockResponseText = "Invalid JSON"
        let mockService = MockLLMService(
            name: "Mock Entity Extractor",
            expectedResult: .success(MockLLMResponse(text: mockResponseText))
        )

        let task = ExtractEntitiesTask(
            llmService: mockService,
            strings: ["Sam Altman works at OpenAI in San Francisco."],
            entityTypes: ["Person", "Organization", "Location"]
        )

        // When/Then
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap the Workflow.Task from the component.")
                return
            }

            _ = try await unwrappedTask.execute()
            XCTFail("Expected an error to be thrown for invalid LLM response, but no error was thrown.")
        } catch {
            XCTAssert(error.localizedDescription.contains("Failed to parse LLM response"), "Error message should indicate parsing failure.")
        }
    }

    func testExtractEntitiesTaskIntegrationWithOllama() async throws {
        // Given
        let stringsToExtractFrom = [
            "Sam Altman works at OpenAI in San Francisco.",
            "Sundar Pichai leads Google, headquartered in Mountain View."
        ]
        let expectedEntities = [
            "Person": ["Sam Altman", "Sundar Pichai"],
            "Organization": ["OpenAI", "Google"],
            "Location": ["San Francisco", "Mountain View"]
        ]

        let ollamaService = OllamaService(name: "OllamaTest")

        let task = ExtractEntitiesTask(
            llmService: ollamaService,
            strings: stringsToExtractFrom,
            entityTypes: ["Person", "Organization", "Location"]
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let outputs = try await unwrappedTask.execute()

        // Then
        guard let entities = outputs["entities"] as? [String: [String]] else {
            XCTFail("Output 'entities' not found or invalid.")
            return
        }

        for (key, values) in expectedEntities {
            XCTAssertEqual(Set(entities[key] ?? []), Set(values), "Extracted \(key) entities do not match expected values.")
        }
    }

    func testExtractEntitiesTaskAmbiguousEntitiesWithOllama() async throws {
        // Given
        let stringsToExtractFrom = [
            "Serena Williams won her final match at the US Open.",
            "The FIFA World Cup was held in Qatar.",
            "New York is home to the Yankees baseball team."
        ]
        let expectedEntities = [
            "Person": ["Serena Williams"],
            "Organization": ["US Open", "FIFA", "Yankees"],
            "Location": ["Qatar", "New York"]
        ]

        let ollamaService = OllamaService(name: "OllamaTest")

        let task = ExtractEntitiesTask(
            llmService: ollamaService,
            strings: stringsToExtractFrom,
            entityTypes: ["Person", "Organization", "Location"]
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let outputs = try await unwrappedTask.execute()

        // Then
        guard let entities = outputs["entities"] as? [String: [String]] else {
            XCTFail("Output 'entities' not found or invalid.")
            return
        }

        for (entityType, expectedValues) in expectedEntities {
            let actualValues = Set(entities[entityType] ?? [])
            XCTAssertTrue(
                Set(expectedValues).isSubset(of: actualValues),
                "The extracted \(entityType) entities do not include all expected values. Expected at least: \(expectedValues). Got: \(actualValues)."
            )
        }
    }

    func testExtractEntitiesTaskNoEntitiesFound() async throws {
        // Given
        let inputStrings = ["This is a random string without any entities."]
        let expectedEntities: [String: [String]] = [
            "Person": [],
            "Organization": [],
            "Location": []
        ]
        let mockResponseText = """
        {
          "entities": {
            "Person": [],
            "Organization": [],
            "Location": []
          }
        }
        """
        let mockService = MockLLMService(
            name: "Mock Entity Extractor",
            expectedResult: .success(MockLLMResponse(text: mockResponseText))
        )

        let task = ExtractEntitiesTask(
            llmService: mockService,
            strings: inputStrings,
            entityTypes: ["Person", "Organization", "Location"]
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let outputs = try await unwrappedTask.execute()

        // Then
        guard let entities = outputs["entities"] as? [String: [String]] else {
            XCTFail("Output 'entities' not found or invalid")
            return
        }
        XCTAssertEqual(entities, expectedEntities, "Extracted entities should match the expected output.")
    }

    func testExtractEntitiesTaskRestrictedEntityTypes() async throws {
        // Given
        let inputStrings = ["Google is based in Mountain View."]
        let expectedEntities: [String: [String]] = [
            "Person": []
        ]
        let mockResponseText = """
        {
          "entities": {
            "Person": []
          }
        }
        """
        let mockService = MockLLMService(
            name: "Mock Entity Extractor",
            expectedResult: .success(MockLLMResponse(text: mockResponseText))
        )

        let task = ExtractEntitiesTask(
            llmService: mockService,
            strings: inputStrings,
            entityTypes: ["Person"] // Restrict to "Person" only
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let outputs = try await unwrappedTask.execute()

        // Then
        guard let entities = outputs["entities"] as? [String: [String]] else {
            XCTFail("Output 'entities' not found or invalid")
            return
        }
        XCTAssertEqual(entities, expectedEntities, "Extracted entities should match the expected output.")
    }

    func testExtractEntitiesTaskComplexSentenceStructure() async throws {
        // Given
        let inputStrings = ["Tesla's Elon Musk announced a new factory in Austin, Texas, alongside SpaceX initiatives."]
        let expectedEntities = [
            "Person": ["Elon Musk"],
            "Organization": ["Tesla", "SpaceX"],
            "Location": ["Austin, Texas"]
        ]
        let mockResponseText = """
        {
          "entities": {
            "Person": ["Elon Musk"],
            "Organization": ["Tesla", "SpaceX"],
            "Location": ["Austin, Texas"]
          }
        }
        """
        let mockService = MockLLMService(
            name: "Mock Entity Extractor",
            expectedResult: .success(MockLLMResponse(text: mockResponseText))
        )

        let task = ExtractEntitiesTask(
            llmService: mockService,
            strings: inputStrings,
            entityTypes: ["Person", "Organization", "Location"]
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let outputs = try await unwrappedTask.execute()

        // Then
        guard let entities = outputs["entities"] as? [String: [String]] else {
            XCTFail("Output 'entities' not found or invalid")
            return
        }
        XCTAssertEqual(entities, expectedEntities, "Extracted entities should match the expected output.")
    }
}
