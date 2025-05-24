//
//  AnalyzeTextReadabilityTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/4/25.
//

import AuroraCore
import AuroraLLM
import Foundation

/**
 `AnalyzeTextReadabilityTask` analyzes the readability of input strings using an LLM service.

 - **Inputs**
    - `strings`: The list of strings to analyze for readability.
    - `maxTokens`: The maximum number of tokens allowed for the LLM response. Defaults to 500.

 - **Outputs**
    - `readabilityScores`: A dictionary where keys are the input strings and values are their readability scores (e.g., Flesch–Kincaid grade level, average word length).
    - `thoughts`: An array of strings containing the LLM's chain-of-thought entries, if any.
    - `rawResponse`: The original unmodified raw response text from the LLM.

 ### Use Cases
 - Assess the complexity of text content for target audiences.
 - Pre-process content to ensure it meets accessibility standards.
 - Compare readability metrics across different content pieces.
 */
public class AnalyzeTextReadabilityTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /**
     Initializes a new `AnalyzeTextReadabilityTask`.

     - Parameters:
        - name: The name of the task.
        - llmService: The LLM service that will handle the readability analysis request.
        - strings: The list of strings to analyze for readability. Defaults to `nil` (can be resolved dynamically).
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
            description: "Analyze the readability of input strings using an LLM service.",
            inputs: inputs
        ) { inputs in
            // Resolve the inputs
            let resolvedStrings = inputs.resolve(key: "strings", fallback: strings) ?? []

            guard !resolvedStrings.isEmpty else {
                throw NSError(
                    domain: "AnalyzeTextReadabilityTask",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No strings provided for readability analysis."]
                )
            }

            // Build the prompt
            let readabilityPrompt = """
            Analyze the readability of the following strings.
            Return the result as a JSON object with each input string as a key and its readability metrics as values. Include metrics like Flesch–Kincaid grade level and average word length.

            Example (for format illustration purposes only):
            Input Strings:
            - "This is a simple sentence."
            - "Using complex syntax and intricate word choice, the author conveyed their ideas."

            Output JSON:
            {
                "This is a simple sentence.": {
                  "FleschKincaidGradeLevel": 2.3,
                  "AverageWordLength": 4.2
                },
                "Using complex syntax and intricate word choice, the author conveyed their ideas.": {
                  "FleschKincaidGradeLevel": 12.5,
                  "AverageWordLength": 6.8
                }
            }

            Important Instructions:
            1. Only analyze the readability metrics of the input strings provided.
            2. Use the Flesch–Kincaid grade level and average word length as the primary metrics.
            3. Do not infer or guess the meaning of the strings—analyze only the readability.
            4. Do not include any additional text, explanations, code, or examples in the output.
            5. Ensure the JSON object is properly formatted and valid.
            6. Ensure the JSON object is properly terminated and complete. Do not cut off or truncate the response.
            7. Do not include anything else, like markdown notation around it or any extraneous characters. The ONLY thing you should return is properly formatted, valid JSON and absolutely nothing else.
            8. Only process the following texts:

            \(resolvedStrings.joined(separator: "\n"))
            """

            let request = LLMRequest(
                messages: [
                    LLMMessage(role: .system, content: "You are a readability analysis expert. Do NOT reveal any reasoning or chain-of-thought. Always respond with a single valid JSON object and nothing else (no markdown, explanations, or code fences)."),
                    LLMMessage(role: .user, content: readabilityPrompt),
                ],
                maxTokens: maxTokens
            )

            do {
                let response = try await llmService.sendRequest(request)

                let fullResponse = response.text
                let (thoughts, rawResponse) = fullResponse.extractThoughtsAndStripJSON()

                // Parse the response into a dictionary (assumes LLM returns JSON-like structure).
                guard let data = rawResponse.data(using: .utf8),
                      let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    throw NSError(
                        domain: "AnalyzeTextReadabilityTask",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse LLM response: \(response.text)"]
                    )
                }

                // Handle both formats: wrapped in "readabilityScores" or direct mapping
                if let wrappedScores = jsonObject["readabilityScores"] {
                    return [
                        "readabilityScores": wrappedScores,
                        "thoughts": thoughts,
                        "rawResponse": fullResponse
                    ]
                } else {
                    // Direct format - jsonResponse IS the readability scores
                    return [
                        "readabilityScores": jsonObject,
                        "thoughts": thoughts,
                        "rawResponse": fullResponse
                    ]
                }
            } catch {
                throw error
            }
        }
    }

    /// Converts this `AnalyzeTextReadabilityTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
