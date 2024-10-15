//
//  LLMServiceTests.swift
//
//
//  Created by Dan Murrell Jr on 9/12/24.
//

import XCTest
@testable import AuroraCore

final class LLMServiceTests: XCTestCase {

    // MARK: - OpenAI Tests

    func testOpenAISendRequest() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            print("OpenAI API key not found, skipping test.")
            return
        }

        let openAIService = OpenAIService(apiKey: apiKey)
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "Test prompt for OpenAI")], model: "gpt-3.5-turbo")

        do {
            let response = try await openAIService.sendRequest(request)
            XCTAssertFalse(response.text.isEmpty, "OpenAI response should not be empty")
        } catch {
            XCTFail("Failed to get a response from OpenAI: \(error)")
        }
    }

    func testOpenAIMissingAPIKey() async throws {
        let openAIService = OpenAIService(apiKey: nil)  // API key is missing
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "Test prompt with missing API key")])

        do {
            _ = try await openAIService.sendRequest(request)
            XCTFail("The request should fail due to missing API key.")
        } catch let error as LLMServiceError {
            XCTAssertEqual(error, .missingAPIKey, "Error should be missingAPIKey")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOpenAIInvalidURL() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            print("OpenAI API key not found, skipping test.")
            return
        }

        let openAIService = OpenAIService(baseURL: "invalid-url", apiKey: apiKey)
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "Test prompt with invalid URL")])

        do {
            _ = try await openAIService.sendRequest(request)
            XCTFail("The request should fail due to an invalid URL.")
        } catch let error as LLMServiceError {
            XCTAssertEqual(error, .invalidURL, "Error should be invalidURL")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Ollama Tests

    func testOllamaSendRequest() async throws {
        let ollamaService = OllamaService(baseURL: "http://localhost:11434")  // Assuming Ollama is running locally
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "Test prompt for Ollama")], model: "llama3.1")

        do {
            let response = try await ollamaService.sendRequest(request)
            XCTAssertFalse(response.text.isEmpty, "Ollama response should not be empty")
        } catch {
            XCTFail("Failed to get a response from Ollama: \(error)")
        }
    }

    func testOllamaInvalidURL() async throws {
        let ollamaService = OllamaService(baseURL: "invalid-url")
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "Test prompt for invalid URL")], model: "llama2")

        do {
            _ = try await ollamaService.sendRequest(request)
            XCTFail("The request should fail due to an invalid URL.")
        } catch let error as LLMServiceError {
            XCTAssertEqual(error, .invalidURL, "Error should be invalidURL")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Anthropic Tests

    func testAnthropicSendRequest() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
            print("Anthropic API key not found, skipping test.")
            return
        }

        let anthropicService = AnthropicService(apiKey: apiKey)
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "Test prompt for Anthropic")], model: "claude-v1")

        do {
            let response = try await anthropicService.sendRequest(request)
            XCTAssertFalse(response.text.isEmpty, "Anthropic response should not be empty")
        } catch {
            XCTFail("Failed to get a response from Anthropic: \(error)")
        }
    }

    func testAnthropicMissingAPIKey() async throws {
        let anthropicService = AnthropicService(apiKey: nil)  // API key is missing
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "Test prompt with missing API key")])

        do {
            _ = try await anthropicService.sendRequest(request)
            XCTFail("The request should fail due to missing API key.")
        } catch let error as LLMServiceError {
            XCTAssertEqual(error, .missingAPIKey, "Error should be missingAPIKey")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAnthropicInvalidURL() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
            print("Anthropic API key not found, skipping test.")
            return
        }

        let anthropicService = AnthropicService(baseURL: "invalid-url", apiKey: apiKey)
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "Test prompt with invalid URL")])

        do {
            _ = try await anthropicService.sendRequest(request)
            XCTFail("The request should fail due to an invalid URL.")
        } catch let error as LLMServiceError {
            XCTAssertEqual(error, .invalidURL, "Error should be invalidURL")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
