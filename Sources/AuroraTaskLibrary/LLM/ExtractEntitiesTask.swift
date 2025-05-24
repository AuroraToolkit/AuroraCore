//
//  ExtractEntitiesTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/3/25.
//

import AuroraCore
import AuroraLLM
import Foundation

/**
  `ExtractEntitiesTask` extracts named entities from a list of strings using an LLM service.

  - **Inputs**
     - `strings`: The array of strings to extract entities from.
     - `entityTypes`: An optional array of entity types to extract (e.g., "Person", "Organization", "Location"). If not provided, all entity types will be extracted.
     - `maxTokens`: The maximum number of tokens allowed for the LLM response. Defaults to 500.

 - **Outputs**
    - `entities`: A dictionary where keys are the entity types and values are arrays of the extracted entities.
    - `thoughts`: An array of strings containing the LLM's chain-of-thought entries, if any.
    - `rawResponse`: The original unmodified raw response text from the LLM.

  ### Use Cases:
  - Extract names, dates, and other entities from user-generated content for analytics or reporting.
  - Enhance search capabilities by tagging documents with extracted entities.
  - Build knowledge graphs or enrich datasets with structured information.

  ### Example:
  **Input Strings:**
  - "Sam Altman is the CEO of OpenAI."
  - "Apple is headquartered in Cupertino, California."

    **Output JSON:**
 ```
 {
     "entities": {
         "Person": ["Sam Altman"],
         "Organization": ["OpenAI", "Apple"],
         "Location": ["Cupertino, California"]
     }
 }
 ```
 */
public class ExtractEntitiesTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /**
     Initializes a new `ExtractEntitiesTask`.

     - Parameters:
        - name: The name of the task.
        - llmService: The LLM service to process entity extraction.
        - strings: The array of strings to process.
        - entityTypes: An optional array of entity types to extract. If not provided, all types will be extracted.
        - maxTokens: The maximum number of tokens allowed for the LLM response. Defaults to 500.
        - inputs: Additional inputs for the task. Defaults to an empty dictionary.
     */
    public init(
        name: String? = nil,
        llmService: LLMServiceProtocol,
        strings: [String]? = nil,
        entityTypes: [String]? = nil,
        maxTokens: Int = 500,
        inputs: [String: Any?] = [:]
    ) {
        task = Workflow.Task(
            name: name ?? String(describing: Self.self),
            description: "Extract named entities from strings using an LLM service",
            inputs: inputs
        ) { inputs in
            let resolvedStrings = inputs.resolve(key: "strings", fallback: strings) ?? []
            guard !resolvedStrings.isEmpty else {
                throw NSError(
                    domain: "ExtractEntitiesTask",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No strings provided for entity extraction."]
                )
            }

            let resolvedEntityTypes = inputs.resolve(key: "entityTypes", fallback: entityTypes)

            // Build the extraction prompt
            var extractionPrompt = """
            Extract named entities from the following strings.
            Return the result as a JSON object where keys are entity types (e.g., "Person", "Organization", "Location") and values are arrays of extracted entities.
            """
            if let types = resolvedEntityTypes, !types.isEmpty {
                extractionPrompt += " Only extract the following types: \(types.joined(separator: ", "))."
            }
            extractionPrompt += """

            Example (for format illustration purposes only):
            Input Strings:
            - "Sam Altman is the CEO of OpenAI."
            - "Apple is headquartered in Cupertino, California."

            Output JSON:
            {
              "Person": ["Sam Altman"],
              "Organization": ["OpenAI", "Apple"],
              "Location": ["Cupertino, California"]
            }

            Important Instructions:
            1. Only extract entities that explicitly appear in the input strings. Do not infer additional entities or names not explicitly mentioned.
            2. Assign entities to the most contextually relevant single category:
               - For example, "US Open" should be categorized as "Organization" when mentioned in the context of an event, not a location.
               - Do not include entities in multiple categories.
            3. Use concise and standardized names:
               - For example, extract "FIFA" instead of "FIFA World Cup" if "FIFA" alone captures the entity's core meaning.
               - Preserve original casing and wording unless explicitly instructed otherwise.
            4. Avoid adding unnecessary context or inferred details (e.g., do not infer "New York Yankees" if only "Yankees" is mentioned).
            5. Return a JSON object with entity types as keys and arrays of entities as values.
            6. Ensure the JSON object is properly formatted and valid.
            7. Ensure the JSON object is properly terminated and complete. Do not cut off or truncate the response.
            8. Do not include anything else, like markdown notation around it or any extraneous characters. The ONLY thing you should return is properly formatted, valid JSON and absolutely nothing else.
            9. Only analyze the following texts:

            \(resolvedStrings.joined(separator: "\n"))
            """

            let request = LLMRequest(
                messages: [
                    LLMMessage(role: .system, content: "You are an expert in named entity recognition. Do NOT reveal any reasoning or chain-of-thought. Always respond with a single valid JSON object and nothing else (no markdown, explanations, or code fences)."),
                    LLMMessage(role: .user, content: extractionPrompt),
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
                        domain: "ExtractEntitiesTask",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse LLM response as JSON."]
                    )
                }

                // Handle both formats: wrapped in "entities" or direct mapping
                if let wrappedEntities = jsonResponse["entities"] as? [String: [String]] {
                    // Already wrapped format: {"entities": {"Person": [...], "Organization": [...]}}
                    return [
                        "entities": wrappedEntities,
                        "thoughts": thoughts,
                        "rawResponse": fullResponse
                    ]
                } else if let directEntities = jsonResponse as? [String: [String]] {
                    // Direct format: {"Person": [...], "Organization": [...]}
                    return [
                        "entities": directEntities,
                        "thoughts": thoughts,
                        "rawResponse": fullResponse
                    ]
                } else {
                    throw NSError(
                        domain: "ExtractEntitiesTask",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Unexpected format for entity extraction response."]
                    )
                }
            } catch {
                throw error
            }
        }
    }

    /// Converts this `ExtractEntitiesTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
