//
//  TranslateStringsTask 2.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/3/25.
//

import Foundation
import AuroraCore
import AuroraLLM

/**
 `TranslateStringsTask` translates a list of strings into a specified target language using an LLM service.

 - **Inputs**
    - `strings`: The list of strings to translate.
    - `targetLanguage`: The target language for the translation (e.g., "fr" for French, "es" for Spanish).
    - `sourceLanguage`: The source language of the strings (optional). Defaults to `nil` (infers the language if not provided).
    - `maxTokens`: The maximum number of tokens to generate in the response. Defaults to `500`.
 - **Outputs**
    - `translations`: A dictionary where keys are the original strings and values are the translated strings.

 ### Use Cases
 - Translate user-generated content into a standard language for consistency in applications.
 - Provide multi-language support for articles, reviews, or other content.
 - Enable real-time translation of chat messages in global communication tools.

 ### Example:
 **Input Strings:**
 - "Hello, how are you?"
 - "This is an example sentence."

 **Target Language:**
 - French

 **Output JSON:**
 ```
{
    “translations”: {
        “Hello, how are you?”: “Bonjour, comment ça va?”,
        “This is an example sentence.”: “Ceci est une phrase d’exemple.”
    }
}
 ```

*/
public class TranslateStringsTask: WorkflowComponent {
   /// The wrapped task.
   private let task: Workflow.Task

   /**
    Initializes a new `TranslateStringsTask`.

    - Parameters:
       - name: The name of the task.
       - llmService: The LLM service used for translation.
       - strings: The list of strings to translate.
       - targetLanguage: The target language for the translation (e.g., "fr" for French).
       - sourceLanguage: The source language of the strings (optional). Defaults to `nil` (infers the language if not provided).
       - maxTokens: The maximum number of tokens to generate in the response. Defaults to 500.
       - inputs: Additional inputs for the task. Defaults to an empty dictionary.
    */
   public init(
       name: String? = nil,
       llmService: LLMServiceProtocol,
       strings: [String]? = nil,
       targetLanguage: String,
       sourceLanguage: String? = nil,
       maxTokens: Int = 500,
       inputs: [String: Any?] = [:]
   ) {
       self.task = Workflow.Task(
           name: name ?? String(describing: Self.self),
           description: "Translate strings into the target language using the LLM service",
           inputs: inputs
       ) { inputs in
           let resolvedStrings = inputs.resolve(key: "strings", fallback: strings) ?? []
           guard !resolvedStrings.isEmpty else {
               throw NSError(
                   domain: "TranslateStringsTask",
                   code: 1,
                   userInfo: [NSLocalizedDescriptionKey: "No strings provided for translation."]
               )
           }

           let resolvedTargetLanguage = inputs.resolve(key: "targetLanguage", fallback: targetLanguage)
           let resolvedSourceLanguage = inputs.resolve(key: "sourceLanguage", fallback: sourceLanguage)

           let translationPrompt = """
           Translate the following text\(resolvedSourceLanguage != nil ? " from \(resolvedSourceLanguage!)" : "") into \(resolvedTargetLanguage).
           
           Return the result as a JSON object with the key "translations", where the **original input string** is used as the key and its translation is the value.

           Important Instructions:
           1. Do not reverse the key-value pairs.
           2. Always use the original input string as the key and the translated string as the value.
           3. Only use the provided input strings. Do not include any additional text, examples, or explanations in the output.
           4. Do not include anything else, like markdown notation around it.
           
           Example:
           Input Strings:
           - "Hello, how are you?"
           - "This is an example sentence."
           
           Source language: English
           Target language: French

           Output JSON:
           {
             "translations": {
               "Hello, how are you?": "Bonjour, comment ça va?",
               "This is an example sentence.": "Ceci est une phrase d'exemple."
             }
           }

           Strings:
           \(resolvedStrings.joined(separator: "\n"))
           """

           let request = LLMRequest(
               messages: [
                   LLMMessage(role: .system, content: "You are a professional translator."),
                   LLMMessage(role: .user, content: translationPrompt)
               ],
               maxTokens: maxTokens
           )

           do {
               let response = try await llmService.sendRequest(request)
               guard
                   let data = response.text.data(using: .utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let translations = jsonObject["translations"] as? [String: String]
               else {
                   throw NSError(
                       domain: "TranslateStringsTask",
                       code: 2,
                       userInfo: [NSLocalizedDescriptionKey: "Failed to parse LLM response."]
                   )
               }
               return ["translations": translations]
           } catch {
               throw error
           }
       }
   }

   /// Converts this `TranslateStringsTask` to a `Workflow.Component`.
   public func toComponent() -> Workflow.Component {
       .task(task)
   }
}
