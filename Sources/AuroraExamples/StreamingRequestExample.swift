//
//  StreamingRequestExample.swift
//  AuroraCore

import Foundation
import AuroraCore
import AuroraLLM

/**
    An example demonstrating how to send a streaming request to the LLM service.
 */
struct StreamingRequestExample {

    func execute() async {
        // Set your Anthropic API key as an environment variable to run this example, e.g., `export ANTHROPIC_API_KEY="your-api-key"`
        let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        if apiKey.isEmpty {
            print("No API key provided. Please set the ANTHROPIC_API_KEY environment variable.")
            return
        }

        // Initialize the LLMManager
        let manager = LLMManager(logger: CustomLogger.shared)

        // Create and register a service
        let realService = AnthropicService(apiKey: apiKey, logger: CustomLogger.shared)
        manager.registerService(realService)

        // Create a request for streaming response
        let messageContent = "What is the meaning of life? Use no more than 2 sentences."
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: messageContent)], stream: true)

        print("Sending streaming request to the LLM service...")
        print("Message content: \(messageContent)")

        // Handle streaming response with a closure for partial responses
        var partialResponses = [String]()
        let onPartialResponse: (String) -> Void = { partialText in
            partialResponses.append(partialText)
            print("Partial response: \(partialText)")
        }

        if let response = await manager.sendStreamingRequest(request, onPartialResponse: onPartialResponse) {
            // Handle the final response
            let vendor = response.vendor ?? "Unknown"
            let model = response.model ?? "Unknown"
            print("Final response received from vendor: \(vendor), model: \(model)\n\(response.text)")
        } else {
            print("No response received, possibly due to an error.")
        }
    }
}
