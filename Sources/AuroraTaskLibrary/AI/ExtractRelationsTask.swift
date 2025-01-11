//
//  ExtractRelationsTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/4/25.
//

import Foundation
import AuroraCore
import AuroraLLM

/**
 `ExtractRelationsTask` extracts relationships between entities mentioned in the input strings.

 - **Inputs**
    - `strings`: The list of strings to analyze for relationships.
    - `relationTypes`: Optional predefined types of relationships to extract (e.g., "works_at", "located_in").
    - `maxTokens`: The maximum number of tokens allowed for the LLM response. Defaults to 500.

 - **Outputs**
    - `relations`: A dictionary where keys are relationship types and values are arrays of tuples representing the entities involved in the relationship.

 ### Use Cases:
 - Extract organizational structures, geographical locations, or professional roles from text.
 - Analyze structured relationships in unstructured data.
 - Create knowledge graphs for downstream tasks.

 ### Example:
 **Input Strings:**
 - "Sam Altman is the CEO of OpenAI, headquartered in San Francisco."
 - "Elon Musk founded SpaceX and Tesla."

 **Output JSON:**

{
“relations”: {
“works_at”: [[“Sam Altman”, “OpenAI”]],
“located_in”: [[“OpenAI”, “San Francisco”]],
“founded”: [[“Elon Musk”, “SpaceX”], [“Elon Musk”, “Tesla”]]
}
}

*/
public class ExtractRelationsTask: WorkflowComponent {
   /// The wrapped task.
   private let task: Workflow.Task

   /**
    Initializes a new `ExtractRelationsTask`.

    - Parameters:
       - name: The name of the task.
       - llmService: The LLM service used for relationship extraction.
       - strings: The list of strings to analyze for relationships.
       - relationTypes: Optional predefined types of relationships to extract.
       - maxTokens: The maximum number of tokens allowed for the LLM response. Defaults to 500.
       - inputs: Additional inputs for the task. Defaults to an empty dictionary.
    */
   public init(
       name: String? = nil,
       llmService: LLMServiceProtocol,
       strings: [String]? = nil,
       relationTypes: [String]? = nil,
       maxTokens: Int = 500,
       inputs: [String: Any?] = [:]
   ) {
       self.task = Workflow.Task(
           name: name ?? String(describing: Self.self),
           description: "Extract relationships from a list of strings.",
           inputs: inputs
       ) { inputs in
           let resolvedStrings = inputs.resolve(key: "strings", fallback: strings) ?? []
           guard !resolvedStrings.isEmpty else {
               throw NSError(
                   domain: "ExtractRelationsTask",
                   code: 1,
                   userInfo: [NSLocalizedDescriptionKey: "No strings provided for relationship extraction."]
               )
           }

           let resolvedRelationTypes = inputs.resolve(key: "relationTypes", fallback: relationTypes)

           // Build the extraction prompt
           var extractionPrompt = """
           Extract relationships between entities in the following strings.
           Return the result as a JSON object where keys are relationship types (e.g., "works_at", "located_in") and values are arrays of entity pairs.
           """
           if let types = resolvedRelationTypes, !types.isEmpty {
               extractionPrompt += " Only extract the following types of relationships: \(types.joined(separator: ", "))."
           }
           extractionPrompt += """
           
           Example (for format illustration purposes only):
           Input Strings:
           - "Steve Jobs was the co-founder of Apple, headquartered in Cupertino, California."
           - "Steve Wozniak co-founded Apple with Steve Jobs."

           Output JSON:
           {
             "relations": {
               "co_founded": [["Steve Jobs", "Apple"], ["Steve Wozniak", "Apple"]],
               "located_in": [["Apple", "Cupertino, California"]]
             }
           }

           Important Instructions:
           1. Analyze the input strings and identify explicit relationships between entities.
           2. Use concise relationship types and entity names.
           3. Do not infer or guess relationships—only extract those explicitly stated.
           4. Ensure the JSON object is properly formatted and valid.
           5. Ensure the JSON object is properly terminated and complete. Do not cut off or truncate the response.
           6. Do not include anything else, like markdown notation around it or any extraneous characters. The ONLY thing you should return is properly formatted, valid JSON and absolutely nothing else.
           7. Only analyze the following texts:

           \(resolvedStrings.joined(separator: "\n"))
           """

           let request = LLMRequest(
               messages: [
                   LLMMessage(role: .system, content: "You are a relationship extraction expert."),
                   LLMMessage(role: .user, content: extractionPrompt)
               ],
               maxTokens: maxTokens
           )

           do {
               let response = try await llmService.sendRequest(request)

               // Strip json markdown if necessary
               let rawResponse = response.text.stripMarkdownJSON()

               guard let data = rawResponse.data(using: .utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let relations = jsonObject["relations"] as? [String: [[String]]]
               else {
                   throw NSError(
                       domain: "ExtractRelationsTask",
                       code: 2,
                       userInfo: [NSLocalizedDescriptionKey: "Failed to parse LLM response."]
                   )
               }
               return ["relations": relations]
           } catch {
               throw error
           }
       }
   }

   /// Converts this `ExtractRelationsTask` to a `Workflow.Component`.
   public func toComponent() -> Workflow.Component {
       .task(task)
   }
}
