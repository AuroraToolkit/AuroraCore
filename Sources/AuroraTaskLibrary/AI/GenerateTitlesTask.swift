//
//  GenerateTitlesTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/4/25.
//


import Foundation
import AuroraCore
import AuroraLLM

/**
 `GenerateTitlesTask` generates succinct and informative titles for a given list of strings using an LLM service.

 - **Inputs**
    - `strings`: The list of strings to generate titles for.
    - `languages`: An optional array of languages (ISO 639-1 format) for the generated titles. Defaults to English if not provided.
    - `maxTokens`: Maximum tokens for the LLM response. Defaults to `100`.
 - **Outputs**
    - `titles`: A dictionary where keys are the original strings and values are dictionaries of generated titles keyed by language.

 ### Use Cases
 - Generate multilingual headlines for articles, blog posts, or content summaries.
 - Suggest titles for user-generated content or creative works in different locales.
 - Simplify and condense complex information into concise titles.
 */
public class GenerateTitlesTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /**
     Initializes a `GenerateTitlesTask` with the required parameters.

     - Parameters:
        - name: Optionally pass the name of the task.
        - llmService: The LLM service to use for title generation.
        - strings: The list of strings to generate titles for. Defaults to `nil` (can be resolved dynamically).
        - languages: An optional array of languages (ISO 639-1 format) for the titles. Defaults to English if not provided.
        - maxTokens: The maximum number of tokens for each title. Defaults to `100`.
        - inputs: Additional inputs for the task. Defaults to an empty dictionary.
     */
    public init(
        name: String? = nil,
        llmService: LLMServiceProtocol,
        strings: [String]? = nil,
        languages: [String]? = nil,
        maxTokens: Int = 100,
        inputs: [String: Any?] = [:]
    ) {
        self.task = Workflow.Task(
            name: name ?? String(describing: Self.self),
            description: "Generate succinct and informative titles for a list of strings using an LLM service.",
            inputs: inputs
        ) { inputs in
            let resolvedStrings = inputs.resolve(key: "strings", fallback: strings) ?? []
            let resolvedLanguages = inputs.resolve(key: "languages", fallback: languages) ?? ["en"]
            let resolvedMaxTokens = inputs.resolve(key: "maxTokens", fallback: maxTokens)

            guard !resolvedStrings.isEmpty else {
                throw NSError(domain: "GenerateTitlesTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "No strings provided for title generation."])
            }

            // Build the prompt
            let prompt = """
            Generate succinct and informative titles for each of the following texts.
            Return the result as a JSON object where keys are the original texts and values are dictionaries with language codes as keys and their generated titles as values.

            Example (for format illustration purposes only):
            Input Texts:
            - "Scientists discover a new element with groundbreaking properties."
            - "The latest smartphone offers features that are revolutionizing the industry."

            Languages: ["en", "es"]

            Output JSON:
            {
              "titles": {
                "Scientists discover a new element with groundbreaking properties.": {
                  "en": "Scientists Unveil Groundbreaking New Element",
                  "es": "Científicos Descubren un Elemento Innovador"
                },
                "The latest smartphone offers features that are revolutionizing the industry.": {
                  "en": "Revolutionary Features in the Latest Smartphone",
                  "es": "Características Revolucionarias del Último Teléfono Inteligente"
                }
              }
            }

            Important Instructions:
            1. Titles should be concise, accurate, and engaging.
            2. Ensure titles are unique and relevant to the content of the text.
            3. Generate titles in the following languages: \(resolvedLanguages.joined(separator: ", ")).
            4. Do not include any additional text, explanations, code, or examples in the output.
            5. The output should ONLY be JSON. Do not include any other formats.
            6. Only process the following texts:

            Texts:
            \(resolvedStrings.joined(separator: "\n"))
            """

            let request = LLMRequest(
                messages: [
                    LLMMessage(role: .system, content: "You are an expert in title generation."),
                    LLMMessage(role: .user, content: prompt)
                ],
                maxTokens: resolvedMaxTokens
            )

            do {
                let response = try await llmService.sendRequest(request)
                // Parse the response
                guard
                    let data = response.text.data(using: .utf8),
                    let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let titles = jsonResponse["titles"] as? [String: [String: String]]
                else {
                    throw NSError(domain: "GenerateTitlesTask", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse LLM response: \(response.text)"])
                }

                return ["titles": titles]
            } catch {
                throw error
            }
        }
    }

    /// Converts this `GenerateTitlesTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
