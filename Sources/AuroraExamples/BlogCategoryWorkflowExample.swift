//
//  BlogCategoryWorkflowExample.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/12/25.
//

import Foundation
import AuroraCore
import AuroraML
import AuroraTaskLibrary
import AuroraLLM
import NaturalLanguage

/**
 Example workflow demonstrating on-device blog post categorization with a
 pre-trained Core ML NLModel, followed by an LLM-powered summary and suggestion
 of up to two new categories.

 Steps:
 * Load your compiled `BlogCategoriesClassifier.mlmodelc` into an `NLModel`.
 * Wrap it in `NLModelClassificationService`.
 * Classify a new blog post to get its current category.
 * Send the post text + predicted category to an LLM to:
    * Generate a one-sentence summary.
    * Suggest up to two additional categories (or an empty list if none apply).
 * Print a final report: summary, classified categories, and any new suggestions.
 */
struct BlogCategoryWorkflowExample {
    func execute() async {
        /// Load a pre-trained Core ML model for blog post categorization.
        let modelsDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("models")
        let modelURL = modelsDir.appendingPathComponent("BlogCategoriesClassifier.mlmodelc")
        guard let model = try? NLModel(contentsOf: modelURL) else {
            print("❌ Could not load BlogCategoriesClassifier.mlmodelc")
            return
        }

        let service = ClassificationService(
            name: "BlogCategories",
            model: model,
            scheme: "category",
            maxResults: 3,
            logger: CustomLogger.shared
        )

        guard let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !openAIKey.isEmpty else {
            print("⚠️ Set OPENAI_API_KEY to run LLM step")
            return
        }
        let llm = OpenAIService(apiKey: openAIKey, logger: CustomLogger.shared)

        let newPost = """
        Migrating Legacy Objective-C Codebases to Swift: Tips and Pitfalls.

        Migrating a large Objective-C codebase to Swift can feel like traversing uncharted territory—but with the right strategy, you can smooth the transition and minimize risk. First, establish clear boundaries for your migration. Rather than attempting a “big bang” rewrite, identify self-contained modules or features that can be converted one at a time. For example, you might start with your networking layer or a utility component that has well-defined inputs and outputs. This incremental approach lets you validate each Swift module in isolation, writing new unit tests in Swift while ensuring your existing Objective-C tests continue to pass.

        As you begin translating code, pay close attention to language interoperability. Swift’s optionals and strong type system can expose latent bugs in your old Objective-C APIs—variables that once tolerated nil may now cause runtime exceptions. Where possible, annotate your Objective-C headers with nullability (nullable/nonnull) and use Swift’s bridging imports to generate safer, more expressive interfaces. You’ll also encounter differences in memory management: ARC is consistent across both languages, but Swift’s value types (structs and enums) behave differently from Objective-C’s reference semantics—so plan to refactor performance-sensitive types into Swift structs carefully, and keep your use of pointers and unsafe operations to a minimum.

        Finally, watch out for behavioral mismatches in Foundation APIs. String handling, collection mutations, and date/time formatting can all behave subtly differently under Swift’s more modern standards. Before you migrate key utility classes, write a suite of integration tests that cover edge cases—empty strings, boundary indices, unusual date formats—and confirm your Swift version matches the Objective-C behavior exactly. Embrace Swift-only patterns like protocol extensions and generics for new code, but don’t be afraid to retain familiar Objective-C idioms until you’ve built confidence in your new Swift modules. With careful planning, incremental rollout, and comprehensive testing, you’ll find that a phased migration delivers the safety of Swift’s modern features without derailing your production schedule.
        """

        // Build and run workflow
        var workflow = Workflow(
            name: "Blog Categorization & Summary",
            description: "Classify, summarize, and suggest categories.",
            logger: CustomLogger.shared
        ) {

            // Classify the post on-device
            Workflow.Task(
                name: "ClassifyPost",
                inputs: ["text": newPost]
            ) { inputs in
                guard let newPost = inputs["text"] as? String else {
                  throw NSError(domain: "ClassifyPost", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing text"])
                }
                let output = try await service.run(request: MLRequest(inputs: ["strings": [newPost]]))
                let tags = output.outputs["tags"] as! [Tag]
                return ["categories": tags]
            }

            // Summarize & suggest via LLM
            Workflow.Task(
                name: "SummarizeAndSuggest",
                inputs: ["categories": "{ClassifyPost.categories}"]
            ) { inputs in
                let tags = inputs["categories"] as! [Tag]
                let cat = tags.map { $0.label }.joined(separator: ", ")
                let text = newPost
                let prompt = """
                A blog post has been auto-categorized as “\(cat)”:

                \(text)

                1) Provide a one-sentence summary.
                2) Suggest up to two additional categories (excluding “\(cat)”). \
                If none apply, return an empty list.

                Respond with JSON only, in this exact shape:
                {
                    "summary": "<one-sentence summary>",
                    "new_categories": ["Cat1","Cat2"]
                }

                Please do not include any other text or formatting, like markdown notation.
                """
                let request = LLMRequest(messages: [
                    LLMMessage(role: .system, content: "You are a helpful assistant."),
                    LLMMessage(role: .user, content: prompt)
                ])
                let response = try await llm.sendRequest(request)
                let data = response.text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .data(using: .utf8)!
                let json = try JSONDecoder().decode(
                    [String: AnyCodable].self,
                    from: data
                )
                return [
                  "summary": json["summary"]?.value as? String ?? "",
                  "suggestions": json["new_categories"]?.value as? [String] ?? []
                ]
            }
        }

        await workflow.start()

        // Print report
        let summary = workflow.outputs["SummarizeAndSuggest.summary"] as? String ?? ""
        let tags = workflow.outputs["ClassifyPost.categories"] as? [Tag] ?? []
        let categories = tags.map(\.label)
        let extras = workflow.outputs["SummarizeAndSuggest.suggestions"] as? [String] ?? []

        print("\n📝 Blog Report:")
        print("• Summary: \(summary)")
        print("• Categories: \(categories.joined(separator: ", "))")
        if extras.isEmpty {
            print("• No new categories suggested.")
        } else {
            print("• New Category Suggestions: \(extras.joined(separator: ", "))")
        }

        print("\n-------\n")

        let report = await workflow.generateReport()
        print(report.printedReport(compact: true, showOutputs: false))

    }
}

// Helper for decoding LLM JSON responses with mixed types
struct AnyCodable: Codable {
    let value: Any
    init<T>(_ v: T) { value = v }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s; return }
        if let a = try? c.decode([String].self) { value = a; return }
        if let d = try? c.decode([String: AnyCodable].self) {
            value = d.mapValues { $0.value }; return
        }
        throw DecodingError.dataCorruptedError(
          in: c,
          debugDescription: "Unsupported JSON type"
        )
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let s as String: try c.encode(s)
        case let a as [String]: try c.encode(a)
        case let d as [String: Any]:
            try c.encode(d.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
              value,
              .init(codingPath: encoder.codingPath,
                    debugDescription: "Unsupported JSON type")
            )
        }
    }
}
