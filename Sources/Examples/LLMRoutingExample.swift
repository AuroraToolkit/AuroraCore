//
//  LLMRoutingExample.swift
//  AuroraCore

import Foundation
import AuroraCore

/**
    An example demonstrating how to route requests between multiple LLM services (Ollama and OpenAI) based on token limits.
 */
struct LLMRoutingExample {

    func execute() async {
        // Fetch the OpenAI API key from the environment
        let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        if openAIKey.isEmpty {
            print("No API key provided. Please set the OPENAI_API_KEY environment variable.")
            return
        }

        // Initialize the LLMManager
        let manager = LLMManager()

        // Register Ollama service with a low context size and token limit
        let ollamaService = OllamaService(
            baseURL: "http://localhost:11434",
            contextWindowSize: 1024,
            maxOutputTokens: 256,
            inputTokenPolicy: .strictRequestLimits,
            outputTokenPolicy: .strictRequestLimits
        )
        manager.registerService(ollamaService)

        // Register OpenAI service which uses a higher context size (128k) and token limit (4k)
        let openAIService = OpenAIService(
            apiKey: openAIKey,
            inputTokenPolicy: .adjustToServiceLimits,
            outputTokenPolicy: .adjustToServiceLimits
        )
        manager.registerService(openAIService)

        print("Registered Services Details:")
        print(" - Ollama: Context Size: \(ollamaService.contextWindowSize), Max Output Tokens: \(ollamaService.maxOutputTokens)")
        print(" - OpenAI: Context Size: \(openAIService.contextWindowSize), Max Output Tokens: \(openAIService.maxOutputTokens)")
        print()

        // Define a high token request
        let highTokenRequest = LLMRequest(
            messages: [LLMMessage(role: .user, content: "Can you explain quantum mechanics in detail?")],
            maxTokens: 500, // Exceeds Ollama's token limit
            stream: false
        )

        // Define a low token request
        let lowTokenRequest = LLMRequest(
            messages: [LLMMessage(role: .user, content: "Summarize the meaning of life in one sentence.")],
            maxTokens: 100, // Fits within Ollama's token limit
            stream: false
        )

        print("\nSending high token request to the LLMManager...")
        print("Prompt: \(highTokenRequest.messages.first?.content ?? "")")
        print("High Token Request Details:")
        print(" - Max Tokens: \(highTokenRequest.maxTokens)")
        print(" - Estimated Token Count: \(highTokenRequest.messages.first?.content.estimatedTokenCount() ?? 0)")

        // Send the high token request
        if let highTokenResponse = await manager.sendRequest(highTokenRequest) {
            print("High Token Request routed to model: \(highTokenResponse.model ?? "Unknown")")
            print("High Token Request Response: \(highTokenResponse.text)")
        } else {
            print("No response received for high token request, possibly due to an error.")
        }

        print("\nSending low token request to the LLM service...")
        print("Prompt: \(lowTokenRequest.messages.first?.content ?? "")")
        print("Low Token Request Details:")
        print(" - Max Tokens: \(lowTokenRequest.maxTokens)")
        print(" - Estimated Token Count: \(lowTokenRequest.messages.first?.content.estimatedTokenCount() ?? 0)")

        // Send the low token request
        if let lowTokenResponse = await manager.sendRequest(lowTokenRequest) {
            print("Low Token Request routed to model: \(lowTokenResponse.model ?? "Unknown")")
            print("Low Token Request Response: \(lowTokenResponse.text)")
        } else {
            print("No response received for low token request, possibly due to an error.")
        }
    }
}
