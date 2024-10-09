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
        let prompt: String

        switch type {
        case .general:
            prompt = "Summarize the following text:\n\(text)"
        case .context:
            prompt = "Summarize the following context:\n\(text)"
        }

        return try await sendToLLM(prompt, options: options)
    }

    public func summarizeGroup(_ texts: [String], type: SummaryType, options: LLMRequestOptions? = nil) async throws -> String {
        let combinedText = texts.joined(separator: "\n")
        let prompt: String

        switch type {
        case .general:
            prompt = "Summarize the following texts:\n\(combinedText)"
        case .context:
            prompt = "Summarize the following context items:\n\(combinedText)"
        }

        return try await sendToLLM(prompt, options: options)
    }

    /**
     Sends the text to the LLM service for summarization and returns the result.

     - Parameter prompt: The prompt to be sent to the LLM service.
     - Returns: The summarized result returned by the LLM service.
     */
    private func sendToLLM(_ prompt: String, options: LLMRequestOptions? = nil) async throws -> String {
        let request = LLMRequest(
            prompt: prompt,
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
