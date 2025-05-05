//
//  DetectLanguagesTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/4/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraLLM
@testable import AuroraTaskLibrary

final class DetectLanguagesTaskTests: XCTestCase {

    func testDetectLanguagesTaskSuccess() async throws {
        // Given
        let mockResponseText = """
        {
          "languages": {
            "Hola, ¿cómo estás?": "es",
            "Bonjour tout le monde": "fr",
            "Hello, how are you?": "en"
          }
        }
        """
        let mockService = MockLLMService(
            name: "Mock Language Detector",
            expectedResult: .success(MockLLMResponse(text: mockResponseText))
        )

        let task = DetectLanguagesTask(
            llmService: mockService,
            strings: ["Hola, ¿cómo estás?", "Bonjour tout le monde", "Hello, how are you?"],
            maxTokens: 500
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let outputs = try await unwrappedTask.execute()

        // Then
        guard let languages = outputs["languages"] as? [String: String] else {
            XCTFail("Output 'languages' not found or invalid.")
            return
        }

        XCTAssertEqual(languages["Hola, ¿cómo estás?"], "es", "Expected Spanish (es) for the first string.")
        XCTAssertEqual(languages["Bonjour tout le monde"], "fr", "Expected French (fr) for the second string.")
        XCTAssertEqual(languages["Hello, how are you?"], "en", "Expected English (en) for the third string.")
    }

    func testDetectLanguagesTaskEmptyInput() async {
        // Given
        let mockService = MockLLMService(
            name: "Mock Language Detector",
            expectedResult: .failure(NSError(domain: "DetectLanguagesTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "No strings provided for detection."]))
        )

        let task = DetectLanguagesTask(
            llmService: mockService,
            strings: [],
            maxTokens: 500
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
            XCTAssertEqual((error as NSError).domain, "DetectLanguagesTask", "Error domain should match.")
            XCTAssertEqual((error as NSError).code, 1, "Error code should match for empty input.")
        }
    }

    func testDetectLanguagesTaskIntegrationWithOllama() async throws {
        // Given
        let stringsToDetect = [
            "Hola, ¿cómo estás?",
            "Bonjour tout le monde",
            "Hello, how are you?"
        ]
        let expectedLanguages: [String: String] = [
            "Hola, ¿cómo estás?": "es",
            "Bonjour tout le monde": "fr",
            "Hello, how are you?": "en"
        ]

        let ollamaService = OllamaService(name: "OllamaTest")

        let task = DetectLanguagesTask(
            llmService: ollamaService,
            strings: stringsToDetect,
            maxTokens: 500
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let outputs = try await unwrappedTask.execute()

        // Then
        guard let languages = outputs["languages"] as? [String: String] else {
            XCTFail("Output 'languages' not found or invalid.")
            return
        }

        for (inputString, expectedLanguage) in expectedLanguages {
            XCTAssertEqual(
                languages[inputString],
                expectedLanguage,
                "Expected language \(expectedLanguage) for string '\(inputString)'."
            )
        }
    }

    func testDetectLanguagesTaskInvalidLLMResponse() async {
        // Given
        let mockResponseText = "Invalid JSON"
        let mockService = MockLLMService(
            name: "Mock Language Detector",
            expectedResult: .success(MockLLMResponse(text: mockResponseText))
        )

        let task = DetectLanguagesTask(
            llmService: mockService,
            strings: ["Hola, ¿cómo estás?"],
            maxTokens: 500
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
}
