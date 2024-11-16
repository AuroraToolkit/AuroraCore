//
//  StreamingRequestExample.swift
//  AuroraCore

import Foundation
import AuroraCore

/**
    An example demonstrating how to send a streaming request to the LLM service.
 */
struct StreamingRequestExample {

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

        // Create a request for streaming response
        let messageContent = "What is the meaning of life? Use no more than 2 sentences."
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: messageContent)], stream: true)

        print("Sending streaming request to the LLM service...")
        print("Message content: \(messageContent)")

        // Handle streaming response with a closure for partial responses
        var partialResponses = [String]()
        let onPartialResponse: (String) -> Void = { partialText in
            partialResponses.append(partialText)
            print("Partial response count: \(partialResponses.count)")
            print("Partial response received: \(partialResponses.joined())")
        }

        if let response = await manager.sendStreamingRequest(request, onPartialResponse: onPartialResponse) {
            // Handle the final response
            print("Final response received: \(response.text)")
        } else {
            print("No response received, possibly due to an error.")
        }
    }
}
