//
//  LLMServiceTests.swift
//  AuroraCoreTests
//
//  Created by Dan Murrell Jr on 9/12/24.
//  Updated on 10/18/24
//

import Foundation
import Testing
@testable import AuroraCore

struct LLMServiceTests {

    // API Keys: Testers should add their own API keys below for OpenAI and Anthropic.
    // Important: Make sure to not commit these keys to the repository!
    private let openAIAPIKey: String? = "" // Insert your OpenAI API key here
    private let anthropicAPIKey: String? = "" // Insert your Anthropic API key here

    // Services to be tested
    private func getServices() -> [LLMServiceProtocol] {
        var services: [LLMServiceProtocol] = []

        if let apiKey = openAIAPIKey, !apiKey.isEmpty {
            services.append(OpenAIService(apiKey: apiKey))
        } else {
            print("Skipping OpenAIService tests - API key not provided")
        }

        if let apiKey = anthropicAPIKey, !apiKey.isEmpty {
            services.append(AnthropicService(apiKey: apiKey))
        } else {
            print("Skipping AnthropicService tests - API key not provided")
        }

        // Ollama service doesn't need an API key
        services.append(OllamaService(baseURL: "http://localhost:11434"))

        return services
    }

    // MARK: - Test cases

    @Test
    func testSendRequestWithBasicPrompt() async throws {
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "Test prompt")])
        let services = getServices()

        for service in services {
            try await sendRequestAndCheckResponse(for: service, with: request)
        }
    }

    @Test
    func testSpecialCharactersAndEmoji() async throws {
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "Testing special characters: @#%&* and emojis 🚀✨")])
        let services = getServices()

        for service in services {
            try await sendRequestAndCheckResponse(for: service, with: request)
        }
    }

    @Test
    func testHandlingLargeInput() async throws {
        let longText = String(repeating: "This is a test input. ", count: 1000)
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: longText)], maxTokens: 512)
        let services = getServices()

        for service in services {
            try await sendRequestAndCheckResponse(for: service, with: request)
        }
    }

    @Test
    func testMultipleMessages() async throws {
        let messages = [
            LLMMessage(role: .system, content: "Act as a helpful assistant."),
            LLMMessage(role: .user, content: "Can you summarize the following text?"),
            LLMMessage(role: .assistant, content: "Certainly! Please provide the text."),
            LLMMessage(role: .user, content: "This is the text I need summarized.")
        ]
        let request = LLMRequest(messages: messages)
        let services = getServices()

        for service in services {
            try await sendRequestAndCheckResponse(for: service, with: request)
        }
    }

    @Test
    func testStreamingResponse() async throws {
        let request = LLMRequest(
            messages: [LLMMessage(role: .user, content: "Test streaming response.")],
            stream: true
        )
        let services = getServices()

        for service in services {
            try await sendRequestAndCheckResponse(for: service, with: request)
        }
    }

    @Test
    func testTokenBias() async throws {
        let logitBias = ["bacon": 2.0]
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "What is your favorite breakfast food?")], options: .init(logitBias: logitBias))
        let services = getServices()

        print("Testing token bias for 'bacon' with services: \(services.map { $0.name })")
        for service in services {
            print("Service: \(service.name)")
            Task {
                try await sendRequestAndCheckResponse(for: service, with: request)
            }
            print("Token bias test completed for \(service.name)")
            print("Services counted: \(services.count)")
        }
    }

    // MARK: - Helper function

    private func sendRequestAndCheckResponse(for service: LLMServiceProtocol, with request: LLMRequest) async throws {
        let response = try await service.sendRequest(request)
        #expect(!response.text.isEmpty, "Response should not be empty for \(service.name)")
        print("Service: \(service.name), Response: \(response.text.prefix(100))...")
    }
}
