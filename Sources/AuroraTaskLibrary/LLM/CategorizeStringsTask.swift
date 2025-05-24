//
//  CategorizeStringsTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/1/25.
//

import AuroraCore
import AuroraLLM
import Foundation

/**
 `CategorizeStringsTask` is a versatile task that categorizes strings into predefined or inferred categories using a language model.

 - **Inputs**
    - `strings`: The list of strings to categorize. This input represents the content you wish to organize into logical groups or topics.
    - `categories`: Optional predefined categories for classification. If provided, the task ensures all strings are grouped into these categories. If not provided, the language model will infer suitable categories based on the content of the strings.

 - **Outputs**
    - `categorizedStrings`: A dictionary where keys are the category names, and values are lists of strings belonging to each category. This output provides a structured way to analyze and use the categorized data.
    - `thoughts`: An array of strings containing the LLM's chain-of-thought entries, if any.
    - `rawResponse`: The original unmodified raw response text from the LLM.

 ### Use Cases
 - **Content Organization**: Automatically group articles, headlines, or other textual content by topic or theme for easier processing.
 - **Knowledge Management**: Categorize knowledge base entries or customer support tickets for efficient searching and retrieval.
 - **Data Analysis**: Pre-process datasets by grouping entries into logical categories for downstream tasks like visualization or reporting.
 - **Dynamic Tagging**: Infer or apply tags/categories to user-generated content in applications like social media or e-commerce platforms.
 - **Custom Applications**: Useful in workflows where contextual grouping or classification of text is a key step.

 ### Example:
 **Input Strings:**
 - "Researchers discover a breakthrough in cancer treatment."
 - "The stock market experienced a significant downturn yesterday."

 **Output JSON:**
 ```
 {
   "categories": {
     "Health": ["Researchers discover a breakthrough in cancer treatment."],
     "Finance": ["The stock market experienced a significant downturn yesterday."]
   }
 }
 ```

 ### Notes
 The task leverages a language model to handle flexible and nuanced categorization needs. When predefined categories are not supplied, the model dynamically determines suitable groupings, making it highly adaptable for unstructured or semi-structured data scenarios.
 */
public class CategorizeStringsTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /**
     Initializes a new `CategorizeStringsTask`.

     - Parameters:
        - name: The name of the task.
        - llmService: The LLM service used for categorization.
        - strings: The list of strings to categorize.
        - categories: Optional predefined categories.
        - maxTokens: The maximum number of tokens to generate in the response. Defaults to 500.
        - inputs: Additional inputs for the task. Defaults to an empty dictionary.
     */
    public init(
        name: String? = nil,
        llmService: LLMServiceProtocol,
        strings: [String]? = nil,
        categories: [String]? = nil,
        maxTokens: Int = 500,
        inputs: [String: Any?] = [:]
    ) {
        task = Workflow.Task(
            name: name ?? String(describing: Self.self),
            description: "Categorize strings using predefined or inferred categories",
            inputs: inputs
        ) { inputs in
            let resolvedStrings = inputs.resolve(key: "strings", fallback: strings) ?? []
            guard !resolvedStrings.isEmpty else {
                throw NSError(
                    domain: "CategorizeStringsTask",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No strings provided for categorization."]
                )
            }

            let resolvedCategories = inputs.resolve(key: "categories", fallback: categories)

            let categorizationInstruction: String
            if let predefinedCategories = resolvedCategories, !predefinedCategories.isEmpty {
                categorizationInstruction = "Categorize the following strings into the predefined categories: \(predefinedCategories.joined(separator: ", "))."
            } else {
                // Both nil and empty array trigger inference
                categorizationInstruction = "Infer appropriate categories for the following strings and categorize them."
            }

            let categorizationPrompt = """
            \(categorizationInstruction)
            Return the result as a JSON object where each category is a key and an array of strings belonging to that category is the value.
            Only return the JSON object, and nothing else.

            Example (for format illustration purposes only):
            Input Strings:
            - "The stock market experienced a significant downturn yesterday."
            - "A new AI tool is revolutionizing how developers write code."

            Categories: ["Finance", "Technology"]

            Output JSON:
            {
              "Finance": ["The stock market experienced a significant downturn yesterday."],
              "Technology": ["A new AI tool is revolutionizing how developers write code."]
            }

            Important Instructions:
            1. Ensure each string is categorized into one or more categories.
            2. Do not include any additional text, explanations, code, or examples in the output.
            3. Ensure the JSON object is properly formatted and valid.
            4. Ensure the JSON object is properly terminated and complete. Do not cut off or truncate the response.
            5. Do not include anything else, like markdown notation around it or any extraneous characters. The ONLY thing you should return is properly formatted, valid JSON and absolutely nothing else.
            6. Only process the following texts:

            \(resolvedStrings.joined(separator: "\n"))
            """

            let request = LLMRequest(
                messages: [
                    LLMMessage(role: .system, content: "You are a text categorization expert. Do NOT reveal any reasoning or chain-of-thought. Always respond with a single valid JSON object and nothing else (no markdown, explanations, or code fences)."),
                    LLMMessage(role: .user, content: categorizationPrompt),
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
                        domain: "CategorizeStringsTask",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse LLM response as JSON."]
                    )
                }

                // Handle both formats: wrapped in "categories" or direct mapping
                if let wrappedCategories = jsonResponse["categories"] as? [String: [String]] {
                    // Already wrapped format: {"categories": {"Finance": [...], "Technology": [...]}}
                    return [
                        "categorizedStrings": wrappedCategories,
                        "thoughts": thoughts,
                        "rawResponse": fullResponse
                    ]
                } else if let directCategories = jsonResponse as? [String: [String]] {
                    // Direct format: {"Finance": [...], "Technology": [...]}
                    return [
                        "categorizedStrings": directCategories,
                        "thoughts": thoughts,
                        "rawResponse": fullResponse
                    ]
                } else {
                    throw NSError(
                        domain: "CategorizeStringsTask",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Unexpected format for categorization response."]
                    )
                }
            } catch {
                throw error
            }
        }
    }

    /// Converts this `CategorizeStringsTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
