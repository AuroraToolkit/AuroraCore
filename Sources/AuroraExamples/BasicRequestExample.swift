//
//  BasicRequestExample.swift
//  AuroraCore

import AuroraCore
import AuroraLLM
import Foundation

/**
    A basic example demonstrating how to send a request to the LLM service.
 */
struct BasicRequestExample {
    func execute() async {
        // Set your Anthropic API key as an environment variable to run this example, e.g., `export ANTHROPIC_API_KEY="your-api-key"`
        let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        if apiKey.isEmpty {
            print("No API key provided. Please set the ANTHROPIC_API_KEY environment variable.")
            return
        }

        // Initialize the LLMManager
        let manager = LLMManager()

        // Create and register a service
        let realService = AnthropicService(apiKey: apiKey, logger: CustomLogger.shared)
        manager.registerService(realService)

        // Create a basic request
        let messageContent = "What is the meaning of life? Use no more than 2 sentences."
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: messageContent)])

        print("Sending request to the LLM service...")
        print("Prompt: \(messageContent)")

        if let response = await manager.sendRequest(request) {
            // Handle the response
            let vendor = response.vendor ?? "Unknown"
            let model = response.model ?? "Unknown"
            print("Response received from vendor: \(vendor), model: \(model)\n\(response.text)")
        } else {
            print("No response received, possibly due to an error.")
        }
    }
}
