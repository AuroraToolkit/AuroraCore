//
//  TranslateStringsTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 12/29/24.
//

import XCTest
@testable import AuroraCore
@testable import AuroraLLM
@testable import AuroraTaskLibrary

final class TranslateStringsTaskTests: XCTestCase {

    func testTranslateStringsTaskSuccess() async throws {
        // Given
        let mockResponseText = """
        {
            "Hello world": "Bonjour tout le monde"
        }
        """
        let mockResponse = MockLLMResponse(text: mockResponseText, vendor: "Test Vendor")
        let mockService = MockLLMService(
            name: "Mock Translator",
            expectedResult: .success(mockResponse)
        )

        let task = TranslateStringsTask(
            llmService: mockService,
            strings: ["Hello world"],
            targetLanguage: "fr"
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let outputs = try await unwrappedTask.execute()

        // Then
        guard let translations = outputs["translations"] as? [String: String] else {
            XCTFail("Output 'translations' not found or invalid.")
            return
        }
        XCTAssertEqual(translations["Hello world"], "Bonjour tout le monde", "The translations should match the expected output.")
    }

    func testTranslateStringsTaskEmptyInput() async {
        // Given
        let mockService = MockLLMService(
            name: "Mock Translator",
            expectedResult: .failure(NSError(domain: "TranslateStringsTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid input text"]))
        )

        let task = TranslateStringsTask(
            llmService: mockService,
            strings: [],
            targetLanguage: "fr"
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
            XCTAssertEqual((error as NSError).domain, "TranslateStringsTask", "Error domain should match.")
            XCTAssertEqual((error as NSError).code, 1, "Error code should match for empty input.")
        }
    }

    func testTranslateStringsTaskInvalidInputs() async {
        // Given
        let mockService = MockLLMService(
            name: "Mock Translator",
            expectedResult: .failure(NSError(domain: "TranslateStringsTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid inputs"]))
        )

        let task = TranslateStringsTask(
            llmService: mockService,
            strings: ["Hello world"],
            targetLanguage: "fr"
        )

        // When/Then
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap the Workflow.Task from the component.")
                return
            }

            _ = try await unwrappedTask.execute(inputs: ["strings": [123]]) // Invalid input type
            XCTFail("Expected an error to be thrown for invalid inputs, but no error was thrown.")
        } catch {
            XCTAssertEqual((error as NSError).domain, "TranslateStringsTask", "Error domain should match.")
            XCTAssertEqual((error as NSError).code, 1, "Error code should match for invalid input.")
        }
    }

    func testTranslateStringsTaskServiceFailure() async {
        // Given
        let expectedError = NSError(domain: "MockLLMService", code: 42, userInfo: [NSLocalizedDescriptionKey: "Simulated service error"])
        let mockService = MockLLMService(
            name: "Mock Translator",
            expectedResult: .failure(expectedError)
        )

        let task = TranslateStringsTask(
            llmService: mockService,
            strings: ["Hello world"],
            targetLanguage: "fr"
        )

        // When/Then
        do {
            guard case let .task(unwrappedTask) = task.toComponent() else {
                XCTFail("Failed to unwrap the Workflow.Task from the component.")
                return
            }

            _ = try await unwrappedTask.execute()
            XCTFail("Expected an error to be thrown by the service, but no error was thrown.")
        } catch {
            XCTAssertEqual((error as NSError).domain, expectedError.domain, "Error domain should match the simulated error.")
            XCTAssertEqual((error as NSError).code, expectedError.code, "Error code should match the simulated error.")
        }
    }

    func testTranslateStringsTaskIntegrationWithOllama() async throws {
        // Given
        let ollamaService = OllamaService(name: "Ollama Translator")
        let task = TranslateStringsTask(
            llmService: ollamaService,
            strings: [
                "Bonjour tout le monde",
                "Comment ça va?"
            ],
            targetLanguage: "en",
            sourceLanguage: "fr"
        )

        // When
        guard case let .task(unwrappedTask) = task.toComponent() else {
            XCTFail("Failed to unwrap the Workflow.Task from the component.")
            return
        }

        let outputs = try await unwrappedTask.execute()

        // Then
        guard let translations = outputs["translations"] as? [String: String] else {
            XCTFail("Output 'translations' not found or invalid.")
            return
        }
        XCTAssertEqual(translations.count, 2, "There should be two translations.")
        XCTAssertEqual(translations["Bonjour tout le monde"], "Hello everyone")
        XCTAssertEqual(translations["Comment ça va?"], "How are you?")

        print("Integration test results: \(translations)")
    }
}
