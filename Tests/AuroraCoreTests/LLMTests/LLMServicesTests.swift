//
//  LLMServicesTests.swift
//  
//
//  Created by Dan Murrell Jr on 9/12/24.
//

import XCTest
@testable import AuroraCore

final class LLMServiceTests: XCTestCase {

    // MARK: - OpenAI Test

    func testOpenAISendRequest() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            print("OpenAI API key not found, skipping test.")
            return
        }

        let openAIService = OpenAIService(apiKey: apiKey)
        let request = LLMRequest(prompt: "Test prompt for OpenAI", model: "text-davinci-003")

        do {
            let response = try await openAIService.sendRequest(request)
            XCTAssertFalse(response.text.isEmpty, "OpenAI response should not be empty")
        } catch {
            XCTFail("Failed to get a response from OpenAI: \(error)")
        }
    }

    // MARK: - Ollama Test

    func testOllamaSendRequest() async throws {
        // Assuming Ollama doesn't require an API key
        let ollamaService = OllamaService()
        let request = LLMRequest(prompt: "Test prompt for Ollama", model: "llama2")

        do {
            let response = try await ollamaService.sendRequest(request)
            XCTAssertFalse(response.text.isEmpty, "Ollama response should not be empty")
        } catch {
            XCTFail("Failed to get a response from Ollama: \(error)")
        }
    }

    // MARK: - Anthropic Test

    func testAnthropicSendRequest() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
            print("Anthropic API key not found, skipping test.")
            return
        }

        let anthropicService = AnthropicService(apiKey: apiKey)
        let request = LLMRequest(prompt: "Test prompt for Anthropic", model: "claude-v1")

        do {
            let response = try await anthropicService.sendRequest(request)
            XCTAssertFalse(response.text.isEmpty, "Anthropic response should not be empty")
        } catch {
            XCTFail("Failed to get a response from Anthropic: \(error)")
        }
    }
}
