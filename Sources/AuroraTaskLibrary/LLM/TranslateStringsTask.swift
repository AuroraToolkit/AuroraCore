//
//  TranslateStringsTask 2.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/3/25.
//

import AuroraCore
import AuroraLLM
import Foundation

/**
  `TranslateStringsTask` translates a list of strings into a specified target language using an LLM service.

  - **Inputs**
     - `strings`: The list of strings to translate.
     - `targetLanguage`: The target language for the translation (e.g., "fr" for French, "es" for Spanish).
     - `sourceLanguage`: The source language of the strings (optional). Defaults to `nil` (infers the language if not provided).
     - `maxTokens`: The maximum number of tokens to generate in the response. Defaults to `500`.
  - **Outputs**
     - `translations`: A dictionary where keys are the original strings and values are the translated strings.
     - `thoughts`: An array of strings containing the LLM's chain-of-thought entries, if any.
     - `rawResponse`: The original unmodified raw response text from the LLM.

  ### Use Cases
  - Translate user-generated content into a standard language for consistency in applications.
  - Provide multi-language support for articles, reviews, or other content.
  - Enable real-time translation of chat messages in global communication tools.

  ### Example:
  **Input Strings:**
  - "Hello, how are you?"
  - "This is an example sentence."

  **Target Language:**
  - French

 **Output JSON:**
 ```
 {
    "Hello, how are you?": "Bonjour, comment ça va?",
    "This is an example sentence.": "Ceci est une phrase d'exemple."
 }
 ```

 */
public class TranslateStringsTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /**
     Initializes a new `TranslateStringsTask`.

     - Parameters:
        - name: The name of the task.
        - llmService: The LLM service used for translation.
        - strings: The list of strings to translate.
        - targetLanguage: The target language for the translation (e.g., "fr" for French).
        - sourceLanguage: The source language of the strings (optional). Defaults to `nil` (infers the language if not provided).
        - maxTokens: The maximum number of tokens to generate in the response. Defaults to 500.
        - inputs: Additional inputs for the task. Defaults to an empty dictionary.
     */
    public init(
        name: String? = nil,
        llmService: LLMServiceProtocol,
        strings: [String]? = nil,
        targetLanguage: String,
        sourceLanguage: String? = nil,
        maxTokens: Int = 500,
        inputs: [String: Any?] = [:]
    ) {
        task = Workflow.Task(
            name: name ?? String(describing: Self.self),
            description: "Translate strings into the target language using the LLM service",
            inputs: inputs
        ) { inputs in
            let resolvedStrings = inputs.resolve(key: "strings", fallback: strings) ?? []
            guard !resolvedStrings.isEmpty else {
                throw NSError(
                    domain: "TranslateStringsTask",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No strings provided for translation."]
                )
            }

            let resolvedTargetLanguage = inputs.resolve(key: "targetLanguage", fallback: targetLanguage)
            let resolvedSourceLanguage = inputs.resolve(key: "sourceLanguage", fallback: sourceLanguage)

            let translationPrompt = """
            Translate the following text\(resolvedSourceLanguage != nil ? " from \(resolvedSourceLanguage!)" : "") into \(resolvedTargetLanguage).

            Return the result as a JSON object where each original string is a key, and the value is the translated string.

            Example (for format illustration purposes only):
            Input Strings:
            - "Hello, how are you?"
            - "This is an example sentence."

            Source language: English
            Target language: French

            Expected Output JSON:
            {
              "Hello, how are you?": "Bonjour, comment ça va?",
              "This is an example sentence.": "Ceci est une phrase d'exemple."
            }

            Important Instructions:
            1. Return the translations as a JSON object mapping original strings to their translations.
            2. Preserve the exact original strings as keys in the JSON object.
            3. Only translate the provided input strings. Do not include any additional text, examples, or explanations in the output.
            4. Escape all special characters in the translations as required for valid JSON, especially double quotes (e.g., use `\"` for `"`).
            5. Ensure the JSON object is properly terminated and complete. Do not cut off or truncate the response.
            6. Ensure the JSON is properly formatted and valid.
            7. Do not include anything else, like markdown notation around it or any extraneous characters. The ONLY thing you should return is properly formatted, valid JSON and absolutely nothing else.
            8. Only process the following texts:

            \(resolvedStrings.joined(separator: "\n"))
            """

            let request = LLMRequest(
                messages: [
                    LLMMessage(role: .system, content: "You are a professional translator. Do NOT reveal any reasoning or chain-of-thought. Always respond with a single valid JSON object and nothing else (no markdown, explanations, or code fences)."),
                    LLMMessage(role: .user, content: translationPrompt),
                ],
                maxTokens: maxTokens
            )

            do {
                let response = try await llmService.sendRequest(request)

                let fullResponse = response.text
                let (thoughts, rawResponse) = fullResponse.extractThoughtsAndStripJSON()

                guard let data = rawResponse.data(using: .utf8),
                      let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    throw NSError(
                        domain: "TranslateStringsTask",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse LLM response as JSON."]
                    )
                }

                // Handle both formats: wrapped in "translations" or direct mapping
                if let wrappedTranslations = jsonResponse["translations"] as? [String: String] {
                    // Already wrapped format: {"translations": {"original": "translated"}}
                    return [
                        "translations": wrappedTranslations,
                        "thoughts": thoughts,
                        "rawResponse": fullResponse
                    ]
                } else if let directTranslations = jsonResponse as? [String: String] {
                    // Direct format: {"original": "translated"}
                    return [
                        "translations": directTranslations,
                        "thoughts": thoughts,
                        "rawResponse": fullResponse
                    ]
                } else {
                    throw NSError(
                        domain: "TranslateStringsTask",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Unexpected format for translation response."]
                    )
                }
            } catch {
                throw error
            }
        }
    }

    /// Converts this `TranslateStringsTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
