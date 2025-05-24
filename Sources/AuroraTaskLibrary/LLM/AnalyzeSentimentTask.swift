//
//  AnalyzeSentimentTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/2/25.
//

import AuroraCore
import AuroraLLM
import Foundation

/**
 `AnalyzeSentimentTask` analyzes the sentiment of a list of strings using an LLM service.

 - **Inputs**
    - `strings`: The list of strings to analyze.
    - `detailed`: Boolean indicating whether to return detailed sentiment analysis. Defaults to `false`.
 - **Outputs**
    - `sentiments`: A dictionary where keys are the input strings and values are their respective sentiments.
    - `thoughts`: An array of strings containing the LLM's chain-of-thought entries, if any.
    - `rawResponse`: The original unmodified raw response text from the LLM.

 ### Use Cases:
 - Understand the emotional tone of user feedback, social media posts, or reviews.
 - Categorize content into positive, neutral, or negative sentiment for analytics or moderation.
 - Identify emotional trends over time in a dataset.

 ### Example:
 **Input Strings**
 - "I love this product!"
 - "The service was okay."
 - "I’m very disappointed with the quality."

 **Output JSON:**
 ```
 {
   "sentiments": {
     "I love this product!": "Positive",
     "The service was okay.": "Neutral",
     "I’m very disappointed with the quality.": "Negative"
   }
 }
 ```

 **Output JSON with detailed analysis:**
 ```
 {
   "sentiments": {
     "I love this product!": {"sentiment": "Positive", "confidence": 95},
     "The service was okay.": {"sentiment": "Neutral", "confidence": 70},
     "I’m very disappointed with the quality.": {"sentiment": "Negative", "confidence": 90}
   }
 }
 ```
 */
public class AnalyzeSentimentTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /**
     Initializes a new `AnalyzeSentimentTask`.

     - Parameters:
        - name: The name of the task.
        - llmService: The LLM service used for sentiment analysis.
        - strings: The list of strings to analyze.
        - detailed: Whether to return detailed sentiment analysis (e.g., confidence scores). Defaults to `false`.
        - maxTokens: The maximum number of tokens to generate in the response. Defaults to 500.
        - inputs: Additional inputs for the task. Defaults to an empty dictionary.
     */
    public init(
        name: String? = nil,
        llmService: LLMServiceProtocol,
        strings: [String]? = nil,
        detailed: Bool = false,
        maxTokens: Int = 500,
        inputs: [String: Any?] = [:]
    ) {
        task = Workflow.Task(
            name: name ?? String(describing: Self.self),
            description: "Analyze the sentiment of a list of strings using an LLM service",
            inputs: inputs
        ) { inputs in
            let resolvedStrings = inputs.resolve(key: "strings", fallback: strings) ?? []
            guard !resolvedStrings.isEmpty else {
                throw NSError(
                    domain: "AnalyzeSentimentTask",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No strings provided for sentiment analysis."]
                )
            }

            let resolvedDetailed = inputs.resolve(key: "detailed", fallback: detailed)

            // Build the prompt for the LLM
            var sentimentPrompt = """
            Analyze the sentiment of the following strings. For each string, return the sentiment (Positive, Neutral, or Negative).

            Return the result as a JSON object with each string as a key and the sentiment as the value.
            Only return the JSON object, and nothing else.

            """

            if resolvedDetailed {
                sentimentPrompt += """
                Return the result as a JSON object where each input string is a key, and the value is an object containing the sentiment (Positive, Neutral, or Negative) and a confidence score as a percentage.

                Example (for format illustration purposes only):
                Input Strings:
                - "I love this product!"
                - "The service was okay."
                - "I'm very disappointed with the quality."

                Expected Output JSON:
                {
                  "I love this product!": {"sentiment": "Positive", "confidence": 95},
                  "The service was okay.": {"sentiment": "Neutral", "confidence": 70},
                  "I'm very disappointed with the quality.": {"sentiment": "Negative", "confidence": 90}
                }
                """
            } else {
                sentimentPrompt += """
                Return the result as a JSON object where each input string is a key, and the value is the sentiment (Positive, Neutral, or Negative).

                Example (for format illustration purposes only):
                Input Strings:
                - "I love this product!"
                - "The service was okay."
                - "I'm very disappointed with the quality."

                Expected Output JSON:
                {
                  "I love this product!": "Positive",
                  "The service was okay.": "Neutral",
                  "I'm very disappointed with the quality.": "Negative"
                }
                """
            }

            sentimentPrompt += """

            Important Instructions:
            1. Only return the JSON object with the sentiment analysis.
            2. Do not include any additional text, examples, or explanations in the output.
            3. Ensure the JSON object is properly formatted and valid.
            4. Ensure the JSON object is properly terminated and complete. Do not cut off or truncate the response.
            5. Do not include anything else, like markdown notation around it or any extraneous characters. The ONLY thing you should return is properly formatted, valid JSON and absolutely nothing else.
            6. Only process the following texts:

            \(resolvedStrings.joined(separator: "\n"))
            """

            let request = LLMRequest(
                messages: [
                    LLMMessage(role: .system, content: "You are a sentiment analysis expert. Do NOT reveal any reasoning or chain-of-thought. Always respond with a single valid JSON object and nothing else (no markdown, explanations, or code fences)."),
                    LLMMessage(role: .user, content: sentimentPrompt),
                ],
                maxTokens: maxTokens
            )

            do {
                let response = try await llmService.sendRequest(request)

                let fullResponse = response.text
                let (thoughts, rawResponse) = fullResponse.extractThoughtsAndStripJSON()

                // Parse the response into a dictionary (assumes LLM returns JSON-like structure).
                guard let data = rawResponse.data(using: .utf8),
                      let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    throw NSError(
                        domain: "AnalyzeSentimentTask",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse LLM response as JSON."]
                    )
                }

                // Handle two formats: wrapped in "sentiments" or direct mapping
                let sentiments: Any
                if let wrappedSentiments = jsonResponse["sentiments"] {
                    // Format: {"sentiments": {...}} - some models might wrap the response in a "sentiments" key
                    sentiments = wrappedSentiments
                } else {
                    // Format: {"string": "sentiment", ...} - direct mapping (preferred)
                    sentiments = jsonResponse
                }

                // Validate and return in consistent wrapped format
                if let detailedSentiments = sentiments as? [String: [String: Any]] {
                    return [
                        "sentiments": detailedSentiments,
                        "thoughts": thoughts,
                        "rawResponse": fullResponse
                    ]
                } else if let simpleSentiments = sentiments as? [String: String] {
                    return [
                        "sentiments": simpleSentiments,
                        "thoughts": thoughts,
                        "rawResponse": fullResponse
                    ]
                } else {
                    throw NSError(
                        domain: "AnalyzeSentimentTask",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Unexpected format for sentiment analysis response."]
                    )
                }
            } catch {
                throw error
            }
        }
    }

    /// Converts this `AnalyzeSentimentTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
