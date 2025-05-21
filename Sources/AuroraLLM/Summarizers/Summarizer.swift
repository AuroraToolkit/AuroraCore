//
//  Summarizer.swift
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

    /**
        Summarizes a text using the LLM service.

        - Parameters:
            - text: The text to summarize.
            - options: The summarization options to configure the LLM response.

        - Returns: The summarized text.
     */
    public func summarize(_ text: String, options: SummarizerOptions? = nil) async throws -> String {
        let messages: [LLMMessage] = [
            LLMMessage(role: .system, content: "Summarize the following text."),
            LLMMessage(role: .user, content: text),
        ]

        return try await sendToLLM(messages, options: options)
    }

    /**
        Summarizes multiple texts using the LLM service.

        - Parameters:
            - texts: An array of texts to summarize.
            - type: The type of summary to generate (e.g., `.single`, or `.multiple`).
            - options: The summarization options to configure the LLM response.

        - Returns: An array of summarized texts corresponding to the input texts.
     */
    public func summarizeGroup(_ texts: [String], type: SummaryType, options: SummarizerOptions? = nil) async throws -> [String] {
        guard !texts.isEmpty else {
            throw NSError(domain: "Summarizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "No texts provided for summarization."])
        }

        switch type {
        case .single:
            // Combine texts into one string and use the existing `summarize` function
            let combinedText = texts.joined(separator: "\n")
            let summary = try await summarize(combinedText, options: options)
            return [summary]

        case .multiple:
            // Use JSON input for structured summarization of individual texts
            let jsonInput: [String: Any] = ["texts": texts]
            let jsonData = try JSONSerialization.data(withJSONObject: jsonInput, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8)!

            // Create messages for the LLM
            let messages: [LLMMessage] = [
                LLMMessage(role: .system, content: summaryInstruction(for: .multiple)),
                LLMMessage(role: .user, content: jsonString),
            ]

            // Send the request to the LLM
            let response = try await sendToLLM(messages, options: options)

            // Parse the JSON response
            guard let responseData = response.data(using: .utf8),
                  let jsonResponse = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let summaries = jsonResponse["summaries"] as? [String]
            else {
                throw NSError(domain: "Summarizer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response from LLM: \(response)"])
            }

            return summaries
        }
    }

    /**
     Constructs the appropriate system-level instruction based on the summary type.

     - Parameter type: The type of summary to generate (e.g., `.single`, or `.multiple`).

     - Returns: The appropriate system instruction for the summary type.
     */
    private func summaryInstruction(for type: SummaryType) -> String {
        switch type {
        case .single:
            return "Summarize the following text:\n"
        case .multiple:
            return """
            You are an assistant that summarizes text. I will provide a JSON object containing a list of texts under the key "texts".
            For each text, provide a concise summary in the same JSON format under the key "summaries".

            For example:
            Input: {"texts": ["Text 1", "Text 2"]}
            Output: {"summaries": ["Summary of Text 1", "Summary of Text 2"]}

            Here is the input:
            """
        }
    }

    /**
     Sends the messages to the LLM service for summarization and returns the result.

     - Parameters:
        - messages: The conversation messages to be sent to the LLM service.
        - options: The summarization options to configure the LLM response.

     - Returns: The summarized result returned by the LLM service.

     - Throws: An error if the LLM service fails to process the request.
     */
    private func sendToLLM(_ messages: [LLMMessage], options: SummarizerOptions? = nil) async throws -> String {
        let maxTokens = min(options?.maxTokens ?? llmService.maxOutputTokens, llmService.maxOutputTokens)
        let request = LLMRequest(
            messages: messages,
            temperature: options?.temperature ?? 0.7,
            maxTokens: maxTokens,
            model: options?.model,
            stream: options?.stream ?? false
        )

        let response = try await llmService.sendRequest(request)
        return response.text
    }
}
