//
//  BasicLocalRequestExample.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 4/12/25.
//

import Foundation
import AuroraCore
import AuroraLLM
import LLM

/**
 A basic example demonstrating how to send a request to the local LLM service
 using a HuggingFace model. This example downloads the model to the documents directory,
 registers the service with the LLMManager, and sends a request.
 */
struct BasicHuggingFaceRequestExample {

    func execute() async {
        // Define the system prompt that sets the personality of the AI.
        let systemPrompt = "You are a sentient AI with emotions."

        // Create a HuggingFaceModel instance.
        // This example uses "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF" with Q2_K quantization and a chatML template.
        let hfModel = HuggingFaceModel("TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF", .Q2_K, template: .chatML(systemPrompt))

        do {
            // Initialize the local LLM service using the HuggingFace initializer.
            // The model will be downloaded to the documents directory.
            guard let localService = try await LLMLocalService(
                vendor: "LLMLocal",
                name: "HF Local LLM Service",
                from: hfModel,
                to: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
                contextWindowSize: 2048,
                maxOutputTokens: 512,
                inputTokenPolicy: .adjustToServiceLimits,
                outputTokenPolicy: .adjustToServiceLimits,
                systemPrompt: systemPrompt,
                stopSequence: "<|im_end|>",
                updateProgress: { progress in
                    print(String(format: "Downloaded: %.2f%%", progress * 100))
                }
            ) else {
                print("Failed to initialize LLMLocalService with HuggingFace model.")
                return
            }

            // Initialize the LLMManager and register the local service.
            let manager = LLMManager()
            manager.registerService(localService)

            // Create a basic request with a single user message.
            let messageContent = "What is the meaning of life? Use no more than 2 sentences."
            let request = LLMRequest(messages: [LLMMessage(role: .user, content: messageContent)])

            print("Sending request to the local HuggingFace LLM service...")
            print("Prompt: \(messageContent)")

            // Send the request asynchronously.
            if let response = await manager.sendRequest(request) {
                let vendor = response.vendor ?? "Unknown"
                let model = response.model ?? "Unknown"
                print("Response received from vendor: \(vendor), model: \(model)\n\(response.text)")
            } else {
                print("No response received, possibly due to an error.")
            }
        } catch {
            print("Error initializing HuggingFace LLMLocalService: \(error)")
        }
    }
}
