//
//  DefaultSummarizer.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/21/24.
//

import Foundation

/**
 The `Summarizer` class provides an implementation of the `SummarizerProtocol`, delegating all summarization tasks to an LLM service.
 */
public class Summarizer: SummarizerProtocol {

    private let llmService: LLMServiceProtocol

    /**
     Initializes a new `Summarizer` instance with the specified LLM service.

     - Parameter llmService: The LLM service to use for summarization.
     */
    public init(llmService: LLMServiceProtocol) {
        self.llmService = llmService
    }

    public func summarize(_ text: String, type: SummaryType, options: LLMRequestOptions? = nil) async throws -> String {
        let messages: [LLMMessage] = [
            LLMMessage(role: .system, content: summaryInstruction(for: type)),
            LLMMessage(role: .user, content: text)
        ]

        return try await sendToLLM(messages, options: options)
    }

    public func summarizeGroup(_ texts: [String], type: SummaryType, options: LLMRequestOptions? = nil) async throws -> String {
        let combinedText = texts.joined(separator: "\n")
        let messages: [LLMMessage] = [
            LLMMessage(role: .system, content: summaryInstruction(for: type)),
            LLMMessage(role: .user, content: combinedText)
        ]

        return try await sendToLLM(messages, options: options)
    }

    /**
     Constructs the appropriate system-level instruction based on the summary type.

     - Parameter type: The type of summary to generate (e.g., general, context).
     - Returns: The appropriate system instruction for the summary type.
     */
    private func summaryInstruction(for type: SummaryType) -> String {
        switch type {
        case .general:
            return "Summarize the following text."
        case .context:
            return "Summarize the following context."
        }
    }

    /**
     Sends the messages to the LLM service for summarization and returns the result.

     - Parameter messages: The conversation messages to be sent to the LLM service.
     - Parameter options: The request options to configure the LLM response.
     - Returns: The summarized result returned by the LLM service.
     */
    private func sendToLLM(_ messages: [LLMMessage], options: LLMRequestOptions? = nil) async throws -> String {
        let request = LLMRequest(
            messages: messages,
            temperature: options?.temperature ?? 0.7,
            maxTokens: options?.maxTokens ?? 256,
            topP: options?.topP ?? 1.0,
            frequencyPenalty: options?.frequencyPenalty ?? 0.0,
            presencePenalty: options?.presencePenalty ?? 0.0,
            stopSequences: options?.stopSequences,
            model: options?.model,
            logitBias: options?.logitBias,
            user: options?.user,
            suffix: options?.suffix,
            stream: options?.stream ?? false
        )

        let response = try await llmService.sendRequest(request)
        return response.text
    }
}
