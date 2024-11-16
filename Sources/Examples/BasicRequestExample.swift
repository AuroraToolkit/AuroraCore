//
//  BasicRequestExample.swift
//  AuroraCore

import Foundation
import AuroraCore

/**
    A basic example demonstrating how to send a request to the LLM service.
 */
struct BasicRequestExample {

    func execute() async {
        let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        if apiKey.isEmpty {
            print("No API key provided. Please set the OPENAI_API_KEY environment variable.")
            return
        }

        // Initialize the LLMManager
        let manager = LLMManager()

        // Create and register a service
        let realService = OpenAIService(apiKey: apiKey)
        manager.registerService(realService)

        // Create a basic request
        let messageContent = "What is the meaning of life? Use no more than 2 sentences."
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: messageContent)])

        print("Sending request to the LLM service...")
        print("Prompt: \(messageContent)")

        if let response = await manager.sendRequest(request) {
            // Handle the response
            print("Response received: \(response.text)")
        } else {
            print("No response received, possibly due to an error.")
        }
    }
}
