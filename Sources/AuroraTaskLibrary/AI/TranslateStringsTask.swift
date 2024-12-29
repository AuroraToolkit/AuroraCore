//
//  TranslateStringsTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 12/29/24.
//

import Foundation
import AuroraCore
import AuroraLLM

/**
 `TranslateStringsTask` translates an array of strings into a target language using an LLM service.

 - **Inputs**
    - `strings`: The array of strings to translate.
    - `targetLanguage`: The target language for the translation (e.g., "fr" for French, "de" for German).
    - `sourceLanguage`: The source language of the text (optional). If not provided, the LLM will infer the language.
    - `maxTokens`: The maximum number of tokens allowed for the LLM response per string being translated. Defaults to 200.
 - **Outputs**
    - `translatedTexts`: The array of translated strings.
 */
public class TranslateStringsTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /**
     Initializes a new `TranslateStringsTask`.

     - Parameters:
        - name: The name of the task.
        - llmService: The LLM service that will handle the translation request.
        - strings: The array of strings to translate. Defaults to `nil` (can be resolved dynamically).
        - sourceLanguage: The source language of the text (optional). Defaults to `nil` (infers the language).
        - targetLanguage: The target language for the translation (e.g., "fr" for French). Defaults to English.
        - maxTokens: The maximum number of tokens allowed for the response per string. Defaults to 200.
        - inputs: Additional inputs for the task. Defaults to an empty dictionary.
     */
    public init(
        name: String? = nil,
        llmService: LLMServiceProtocol,
        strings: [String]? = nil,
        sourceLanguage: String? = nil,
        targetLanguage: String = "en",
        maxTokens: Int = 200,
        inputs: [String: Any?] = [:]
    ) {
        self.task = Workflow.Task(
            name: name ?? String(describing: Self.self),
            description: "Translate an array of strings from \(sourceLanguage ?? "inferred language") to \(targetLanguage)",
            inputs: inputs
        ) { inputs in
            /// Resolve the strings, target language, source language, and max tokens from inputs
            let resolvedStrings = inputs.resolve(key: "strings", fallback: strings) ?? []
            let resolvedTargetLanguage = inputs.resolve(key: "targetLanguage", fallback: targetLanguage)
            let resolvedSourceLanguage = inputs.resolve(key: "sourceLanguage", fallback: sourceLanguage)
            let resolvedMaxTokens = inputs.resolve(key: "maxTokens", fallback: maxTokens)

            guard !resolvedStrings.isEmpty else {
                throw NSError(
                    domain: "TranslateStringsTask",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No strings provided for translation."]
                )
            }

            var translatedStrings = [String]()

            for string in resolvedStrings {
                // Build the translation prompt
                let translationPrompt: String
                if let sourceLang = resolvedSourceLanguage {
                    translationPrompt = "Translate the following text from \(sourceLang) to \(resolvedTargetLanguage): \(string)"
                } else {
                    translationPrompt = "Translate the following text into \(resolvedTargetLanguage): \(string)"
                }

                let request = LLMRequest(
                    messages: [
                        LLMMessage(role: .system, content: "You are a professional translator."),
                        LLMMessage(role: .user, content: translationPrompt)
                    ],
                    maxTokens: resolvedMaxTokens
                )

                do {
                    let response = try await llmService.sendRequest(request)
                    translatedStrings.append(response.text)
                } catch {
                    throw error
                }
            }

            return ["translatedStrings": translatedStrings]
        }
    }

    /// Converts this `TranslateStringsTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
