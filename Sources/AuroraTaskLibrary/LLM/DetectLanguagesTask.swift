//
//  DetectLanguagesTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/4/25.
//

import AuroraCore
import AuroraLLM
import Foundation

/**
  `DetectLanguagesTask` identifies the language(s) of the provided strings using an LLM service.

  - **Inputs**
     - `strings`: An array of strings for which the language needs to be detected.
     - `maxTokens`: The maximum number of tokens allowed for the LLM response. Defaults to 500.
  - **Outputs**
     - `languages`: A dictionary where the keys are the input strings, and the values are the detected language codes (e.g., "en" for English, "fr" for French).
     - `thoughts`: An array of strings containing the LLM's chain-of-thought entries, if any.
     - `rawResponse`: The original unmodified raw response text from the LLM.

  ### Use Cases
  - Analyze user-generated content to understand the languages used.
  - Preprocess multilingual datasets for translation or other tasks.
  - Detect and handle language-specific workflows in applications.

  ### Example:
  **Input Strings:**
  - "Bonjour tout le monde."
  - "Hello world!"

 **Output JSON:**
 ```
 {
     "languages": {
         "Bonjour tout le monde.": "fr",
         "Hello world!": "en"
     }
 }
 ```
 */
public class DetectLanguagesTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /**
     Initializes a `DetectLanguagesTask` with the required parameters.

     - Parameters:
        - name: Optionally pass the name of the task.
        - llmService: The LLM service used for language detection.
        - strings: The list of strings to analyze. Defaults to `nil` (can be resolved dynamically).
        - maxTokens: The maximum number of tokens allowed for the response. Defaults to 500.
        - inputs: Additional inputs for the task. Defaults to an empty dictionary.
     */
    public init(
        name: String? = nil,
        llmService: LLMServiceProtocol,
        strings: [String]? = nil,
        maxTokens: Int = 500,
        inputs: [String: Any?] = [:]
    ) {
        task = Workflow.Task(
            name: name ?? String(describing: Self.self),
            description: "Detect languages for the provided strings",
            inputs: inputs
        ) { inputs in
            /// Resolve the strings from the inputs or use the provided parameter
            let resolvedStrings = inputs.resolve(key: "strings", fallback: strings) ?? []

            guard !resolvedStrings.isEmpty else {
                throw NSError(domain: "DetectLanguagesTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "No strings provided for language detection."])
            }

            // Build the detection prompt
            let detectionPrompt = """
            Your job is to detect the language of a set of provided text strings, and format your results as JSON.
            You must return the results as a JSON object with the original strings as keys and their detected language codes (ISO 639-1 format) as values.
            Only return the JSON object, and nothing else.

            Example (for format illustration purposes only):
            Input Strings:
            - "Bonjour tout le monde."
            - "Hello world!"

            Output JSON:
            {
              "Bonjour tout le monde.": "fr",
              "Hello world!": "en"
            }

            Important Instructions:
            1. Analyze the input strings and determine the language of each string.
            2. Use ISO 639-1 format for language codes (e.g., "es" for Spanish, "fr" for French).
            3. Return the result as a JSON object with the original strings as keys and their detected language codes as values.
            4. Ensure the JSON object is properly terminated and complete. Do not cut off or truncate the response.
            5. Ensure the JSON object is formatted correctly.
            6. Do not infer or guess the meaning of strings—only analyze the languages explicitly present.
            7. Do not include anything else, like markdown notation around it or any extraneous characters.
            8. The *ONLY* thing you should return is properly formatted, valid JSON and absolutely nothing else.
            9. Only analyze the following texts:

            \(resolvedStrings.joined(separator: "\n"))
            """

            let request = LLMRequest(
                messages: [
                    LLMMessage(role: .system, content: "You are a language detection expert. Do NOT reveal any reasoning or chain-of-thought. Always respond with a single valid JSON object and nothing else (no markdown, explanations, or code fences)."),
                    LLMMessage(role: .user, content: detectionPrompt),
                ],
                maxTokens: maxTokens
            )

            do {
                let response = try await llmService.sendRequest(request)

                let fullResponse = response.text
                let (thoughts, rawResponse) = fullResponse.extractThoughtsAndStripJSON()

                // Parse the response into a dictionary
                guard let data = rawResponse.data(using: .utf8),
                      let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    throw NSError(
                        domain: "DetectLanguagesTask", 
                        code: 2, 
                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse LLM response as JSON."]
                    )
                }

                // Handle both formats: wrapped in "languages" or direct mapping
                if let wrappedLanguages = jsonResponse["languages"] as? [String: String] {
                    // Already wrapped format: {"languages": {"text": "en"}}
                    return [
                        "languages": wrappedLanguages,
                        "thoughts": thoughts,
                        "rawResponse": fullResponse
                    ]
                } else if let directLanguages = jsonResponse as? [String: String] {
                    // Direct format: {"text": "en"}
                    return [
                        "languages": directLanguages,
                        "thoughts": thoughts,
                        "rawResponse": fullResponse
                    ]
                } else {
                    throw NSError(
                        domain: "DetectLanguagesTask",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Unexpected format for language detection response."]
                    )
                }
            } catch {
                throw error
            }
        }
    }

    /// Converts this `DetectLanguagesTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
