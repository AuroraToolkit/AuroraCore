//
//  ClusterStringsTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/1/25.
//

import Foundation
import AuroraCore
import AuroraLLM

/**
 `ClusterStringsTask` groups strings into clusters based on semantic similarity, without requiring predefined categories.

 - **Inputs**
    - `strings`: The list of strings to cluster.
    - `maxClusters`: Optional maximum number of clusters to create. If not provided, the LLM determines the optimal number dynamically.
 - **Outputs**
    - `clusters`: A dictionary where keys are cluster IDs or inferred names, and values are lists of strings belonging to each cluster.

### Use Cases:
- **Customer Feedback Analysis**: Grouping customer reviews or feedback to identify trends.
- **Content Clustering**: Organizing blog posts, news articles, or research papers into topic-based clusters.
- **Unsupervised Data Exploration**: Automatically grouping strings for exploratory analysis when categories are unknown.
- **Semantic Deduplication**: Identifying and grouping similar strings to detect duplicates or near-duplicates.

 ### Example:
 **Input Strings:**
 - "The stock market dropped today."
 - "AI is transforming software development."
 - "The S&P 500 index fell by 2%."

 **Output JSON:**
 ```
 {
   "Cluster 1": ["The stock market dropped today.", "The S&P 500 index fell by 2%."],
   "Cluster 2": ["AI is transforming software development."]
 }
 ```
*/
public class ClusterStringsTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /**
     Initializes a new `ClusterStringsTask`.

     - Parameters:
        - name: The name of the task.
        - llmService: The LLM service used for clustering.
        - strings: The list of strings to cluster.
        - maxClusters: Optional maximum number of clusters to create.
        - maxTokens: The maximum number of tokens to generate in the response. Defaults to 500.
        - inputs: Additional inputs for the task. Defaults to an empty dictionary.
     */
    public init(
        name: String? = nil,
        llmService: LLMServiceProtocol,
        strings: [String]? = nil,
        maxClusters: Int? = nil,
        maxTokens: Int = 500,
        inputs: [String: Any?] = [:]
    ) {
        self.task = Workflow.Task(
            name: name ?? String(describing: Self.self),
            description: "Cluster strings into groups based on semantic similarity.",
            inputs: inputs
        ) { inputs in
            let resolvedStrings = inputs.resolve(key: "strings", fallback: strings) ?? []
            guard !resolvedStrings.isEmpty else {
                throw NSError(
                    domain: "ClusterStringsTask",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No strings provided for clustering."]
                )
            }

            let resolvedMaxClusters = inputs.resolve(key: "maxClusters", fallback: maxClusters)

            // Build the prompt for the LLM
            var clusteringPrompt = """
            Cluster the following strings based on semantic similarity. Return the result as a JSON object with cluster IDs as keys and arrays of strings as values.
            Only return the JSON object, and nothing else.

            """

            if let maxClusters = resolvedMaxClusters {
                clusteringPrompt += " Limit the number of clusters to \(maxClusters)."
            }

            clusteringPrompt += """
            
            Example (for format illustration purposes only):
            Input Strings:
            - "The stock market dropped today."
            - "AI is transforming software development."
            - "The S&P 500 index fell by 2%."

            Output JSON:
            {
              "Cluster 1": ["The stock market dropped today.", "The S&P 500 index fell by 2%."],
              "Cluster 2": ["AI is transforming software development."]
            }

            Important Instructions:
            1. Do not include any other text, examples, or explanations in the output.
            2. Only return the JSON object with cluster IDs and string arrays.
            3. Ensure that the clusters are meaningful and relevant.
            4. Cluster the strings based on **semantic meaning and context**. Strings that describe similar topics, themes, or ideas should belong to the same cluster. For example:
                - Group strings about technology or artificial intelligence together.
                - Group strings about finance, economy, or stock markets together. 
            5. Only use the following strings, and do not use the examples in the prompt.
            
            Strings:
            \(resolvedStrings.joined(separator: "\n"))
            """

            let request = LLMRequest(
                messages: [
                    LLMMessage(role: .system, content: "You are an expert in semantic similarity clustering."),
                    LLMMessage(role: .user, content: clusteringPrompt)
                ],
                maxTokens: maxTokens
            )

            do {
                let response = try await llmService.sendRequest(request)
                // Parse the response into a dictionary (assumes LLM returns JSON-like structure).
                guard let data = response.text.data(using: .utf8),
                      let clusters = try? JSONSerialization.jsonObject(with: data) as? [String: [String]] else {
                    throw NSError(
                        domain: "ClusterStringsTask",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse LLM response."]
                    )
                }
                return ["clusters": clusters]
            } catch {
                throw error
            }
        }
    }

    /// Converts this `ClusterStringsTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
