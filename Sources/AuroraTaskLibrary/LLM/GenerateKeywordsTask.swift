//
//  GenerateKeywordsTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/2/25.
//

import Foundation
import AuroraCore
import AuroraLLM

/**
 `GenerateKeywordsTask` extracts and optionally categorizes keywords from a list of strings using an LLM service.

 - **Inputs**
    - `strings`: The list of strings to extract keywords from.
    - `maxKeywords`: Maximum number of keywords to generate per string. Defaults to `5`.
    - `categories`: Optional predefined categories for grouping keywords. If provided, keywords will be grouped under these categories.
 - **Outputs**
    - `keywords`: A dictionary where keys are input strings and values are arrays of generated keywords.
    - `categorizedKeywords`: A dictionary of categories mapping to their associated keywords (if categories are provided).

 ### Use Cases:
 - Summarize the main topics or themes of articles, blogs, or reports.
 - Organize keywords into logical categories for better interpretation.
 - Extract key terms from user feedback or reviews for data analysis.
*/
public class GenerateKeywordsTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /**
     Initializes a new `GenerateKeywordsTask`.

     - Parameters:
        - name: The name of the task.
        - llmService: The LLM service to use for generating keywords.
        - strings: The list of strings to extract keywords from.
        - categories: Optional predefined categories for grouping keywords.
        - maxKeywords: The maximum number of keywords per string. Defaults to 5.
        - maxTokens: The maximum number of tokens to generate in the response. Defaults to 500.
        - inputs: Additional inputs for the task. Defaults to an empty dictionary.
    */
    public init(
        name: String? = nil,
        llmService: LLMServiceProtocol,
        strings: [String]? = nil,
        categories: [String]? = nil,
        maxKeywords: Int = 5,
        maxTokens: Int = 500,
        inputs: [String: Any?] = [:]
    ) {
        self.task = Workflow.Task(
            name: name ?? String(describing: Self.self),
            description: "Generate and categorize keywords from a list of strings",
            inputs: inputs
        ) { inputs in
            let resolvedStrings = inputs.resolve(key: "strings", fallback: strings) ?? []
            guard !resolvedStrings.isEmpty else {
                throw NSError(
                    domain: "GenerateKeywordsTask",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No strings provided for keyword generation."]
                )
            }

            let resolvedCategories = inputs.resolve(key: "categories", fallback: categories)
            let resolvedMaxKeywords = inputs.resolve(key: "maxKeywords", fallback: maxKeywords)

            let categorizationInstruction: String
            if let predefinedCategories = resolvedCategories, !predefinedCategories.isEmpty {
                categorizationInstruction = """
                Categorize the extracted keywords into these predefined categories: \(predefinedCategories.joined(separator: ", ")).
                """
            } else {
                categorizationInstruction = "Categorize the extracted keywords into inferred categories."
            }

            // Build the prompt for the LLM
            let keywordsPrompt = """
            Extract up to \(resolvedMaxKeywords) significant and meaningful keywords from the following strings, and organize them into categories.

            \(categorizationInstruction)

            Return the result as a JSON object:
            - If categories are provided, the output should include a `categorizedKeywords` key mapping categories to keywords.
            - If no categories are provided, the output should include inferred categories.

            Example (for format illustration purposes only):
            Input Strings:
            - "The stock market experienced a significant downturn yesterday."
            - "A new AI tool is revolutionizing how developers write code."
            
            Output JSON:
            {
              "keywords": {
                "The stock market experienced a significant downturn yesterday.": ["stock market", "downturn", "yesterday"],
                "A new AI tool is revolutionizing how developers write code.": ["AI", "developers", "write code"]
              },
              "categorizedKeywords": {
                "Stocks and the Economy": ["stock market", "downturn"],
                "Software and Tech": ["AI", "developers", "write code"]
              }
            }

            Important instructions:
            1. Focus on extracting keywords that are relevant and specific to the content.
            2. Avoid generic terms or phrases that do not add value to the keyword list.
            3. Ensure the keywords are sgnificant, meaningful, and capture the main ideas or topics of the content.
            4. For the `keywords` object, the key should be the original string, and the value should be an array of keywords for that string.
            5. Ensure the JSON object is properly formatted and valid.
            6. Ensure the JSON object is properly terminated and complete. Do not cut off or truncate the response.
            7. Do not include anything else, like markdown notation around it or any extraneous characters. The ONLY thing you should return is properly formatted, valid JSON and absolutely nothing else.
            8. Only analyze the following texts:

            \(resolvedStrings.joined(separator: "\n"))
            """

            let request = LLMRequest(
                messages: [
                    LLMMessage(role: .system, content: "You are an expert in keyword extraction and categorization."),
                    LLMMessage(role: .user, content: keywordsPrompt)
                ],
                maxTokens: maxTokens
            )

            do {
                let response = try await llmService.sendRequest(request)

                // Strip JSON markdown if necessary
                let rawResponse = response.text.stripMarkdownJSON()

                // Parse the response into a dictionary.
                guard let data = rawResponse.data(using: .utf8),
                      let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    throw NSError(
                        domain: "GenerateKeywordsTask",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse LLM response."]
                    )
                }

                var outputs: [String: Any] = [:]
                if let keywords = jsonResponse["keywords"] as? [String: [String]] {
                    outputs["keywords"] = keywords
                }
                if let categorizedKeywords = jsonResponse["categorizedKeywords"] as? [String: [String]] {
                    outputs["categorizedKeywords"] = categorizedKeywords
                }

                return outputs
            } catch {
                throw error
            }
        }
    }

    /// Converts this `GenerateKeywordsTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
