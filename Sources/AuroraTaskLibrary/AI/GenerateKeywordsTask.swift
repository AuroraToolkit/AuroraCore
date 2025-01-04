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
 `GenerateKeywordsTask` extracts keywords from a list of strings using an LLM service.

 - **Inputs**
    - `strings`: The list of strings to extract keywords from.
    - `maxKeywords`: Maximum number of keywords to generate per string. Defaults to `5`.
 - **Outputs**
    - `keywords`: A dictionary where keys are input strings and values are arrays of generated keywords.

 ### Use Cases:
 - Summarize the main topics or themes of articles, blogs, or reports.
 - Optimize content for search engine rankings by generating targeted keywords.
 - Extract key terms from user feedback or reviews for data analysis.

 ### Example:
 **Input Strings:**
 - "AI is transforming the healthcare industry."
 - "Quantum computing will revolutionize cryptography."

 **Output JSON:**
```
 {
    “keywords”: {
        “AI is transforming the healthcare industry.”: [“AI”, “healthcare”, “industry”, “transformation”],
        “Quantum computing will revolutionize cryptography.”: [“quantum computing”, “cryptography”, “revolution”]
    }
 }
```
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
       - maxKeywords: The maximum number of keywords per string. Defaults to 5.
       - maxTokens: The maximum number of tokens to generate in the response. Defaults to 500.
       - inputs: Additional inputs for the task. Defaults to an empty dictionary.
    */
   public init(
       name: String? = nil,
       llmService: LLMServiceProtocol,
       strings: [String]? = nil,
       maxKeywords: Int = 5,
       maxTokens: Int = 500,
       inputs: [String: Any?] = [:]
   ) {
       self.task = Workflow.Task(
           name: name ?? String(describing: Self.self),
           description: "Generate keywords from a list of strings",
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

           let resolvedMaxKeywords = inputs.resolve(key: "maxKeywords", fallback: maxKeywords)

           // Build the prompt for the LLM
           let keywordsPrompt = """
           Extract up to \(resolvedMaxKeywords) significant and meaningful keywords from the following strings. Focus on terms that capture the essence or main ideas of the content. Avoid generic or overly broad terms (e.g., "sources", "like").

           Return the result as a JSON object with each string as a key and an array of keywords as the value.
           Only return the JSON object, and nothing else.

            Example (for format illustration purposes only):
           Input Strings:
           - "AI is transforming the healthcare industry."
           - "Quantum computing will revolutionize cryptography."

           Output JSON:
           {
             "keywords": {
               "AI is transforming the healthcare industry.": ["AI", "healthcare", "industry", "transformation"],
               "Quantum computing will revolutionize cryptography.": ["quantum computing", "cryptography", "revolution"]
             }
           }

           Important: Only use the following input strings for keyword generation. Do not include the example strings in the output.

           Strings:
           \(resolvedStrings.joined(separator: "\n"))
           """

           let request = LLMRequest(
               messages: [
                   LLMMessage(role: .system, content: "You are an expert in keyword extraction."),
                   LLMMessage(role: .user, content: keywordsPrompt)
               ],
               maxTokens: maxTokens
           )

           do {
               let response = try await llmService.sendRequest(request)
               // Parse the response into a dictionary.
               guard
                   let data = response.text.data(using: .utf8),
                   let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let keywords = jsonResponse["keywords"] as? [String: [String]]
               else {
                   throw NSError(
                       domain: "GenerateKeywordsTask",
                       code: 2,
                       userInfo: [NSLocalizedDescriptionKey: "Failed to parse LLM response."]
                   )
               }
               return ["keywords": keywords]
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
