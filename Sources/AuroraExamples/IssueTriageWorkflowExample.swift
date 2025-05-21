//
//  IssueTriageWorkflowExample.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/18/25.
//

import AuroraCore
import AuroraML
import AuroraTaskLibrary
import Foundation
import NaturalLanguage

/**
 Example workflow demonstrating triage of a GitHub issue:

 1.  Classify the issue type (bug_report, feature_request, question)
 2.  Extract the primary intent (top label)
 3.  Tag any error codes or code tokens via NLTagger
 4.  Semantic‐search against a static “past issues” corpus

 The final report prints:
 • Candidate issue types
 • Primary intent
 • Extracted code/error tokens
 • Top-K matching past issues
 */
struct IssueTriageWorkflowExample {
    // Your “past issues” knowledge base
    private let pastIssues: [String] = [
        "App crashes when clicking Save",
        "Add dark mode toggle",
        "Login fails with error E401",
        "How do I export data as CSV?",
        "Search returns no results",
        "Feature: schedule automated reports",
    ]

    /// Runs the triage workflow on a single issue text.
    func execute(on issueText: String) async {
        print("🔍 Analyzing issue...")
        print("• Issue text: \(issueText)\n")

        // Load your issue‐type classifier
        let modelsDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("models")
        let modelURL = modelsDir.appendingPathComponent("SupportTicketsClassifier.mlmodelc")
        guard let issueModel = try? NLModel(contentsOf: modelURL) else {
            print("❌ Could not load issue‐classifier model")
            return
        }
        let classificationService = ClassificationService(
            name: "IssueClassifier",
            model: issueModel,
            scheme: "issueType",
            maxResults: 2,
            logger: CustomLogger.shared
        )

        // Intent extractor (same model, top-1 result)
        let intentService = IntentExtractionService(
            model: issueModel,
            maxResults: 1,
            logger: CustomLogger.shared
        )

        // Tagging service for error-codes & tokens
        let taggingService = TaggingService(
            name: "CodeTagger",
            schemes: [.nameType],
            unit: .word,
            options: [.omitWhitespace, .omitPunctuation],
            logger: CustomLogger.shared
        )

        // Semantic-search past issues
        guard let embedModel = NLEmbedding.sentenceEmbedding(for: .english) else {
            print("❌ Embedding model unavailable")
            return
        }
        let embeddingService = EmbeddingService(
            name: "SentenceEmbedding",
            embedding: embedModel
        )
        let searchService = SemanticSearchService(
            name: "PastIssueSearch",
            embeddingService: embeddingService,
            documents: pastIssues,
            topK: 3
        )

        // Compose the workflow
        var workflow = Workflow(
            name: "IssueTriage",
            description: "Classify, extract intent, tag code, and search past issues"
        ) {
            // Classification
            Workflow.Task(name: "ClassifyIssue", inputs: ["text": issueText]) { inputs in
                let text = inputs["text"] as! String
                let resp = try await classificationService.run(
                    request: MLRequest(inputs: ["strings": [text]])
                )
                let tags = resp.outputs["tags"] as! [Tag]
                return ["candidates": tags]
            }

            // Intent extraction
            Workflow.Task(name: "ExtractIntent", inputs: ["text": issueText]) { inputs in
                let text = inputs["text"] as! String
                let resp = try await intentService.run(
                    request: MLRequest(inputs: ["strings": [text]])
                )
                let intents = resp.outputs["intents"] as! [[String: Any]]
                return ["intent": intents]
            }

            // Error-code tagging
            Workflow.Task(name: "TagCodes", inputs: ["strings": [issueText]]) { inputs in
                let texts = inputs["strings"] as! [String]
                let resp = try await taggingService.run(
                    request: MLRequest(inputs: ["strings": texts])
                )
                let codes = resp.outputs["tags"] as! [[Tag]]
                return ["codes": codes]
            }

            // Semantic-search past issues
            Workflow.Task(name: "SearchPastIssues", inputs: ["query": issueText]) { inputs in
                let q = inputs["query"] as! String
                let resp = try await searchService.run(
                    request: MLRequest(inputs: ["query": q])
                )
                let results = resp.outputs["results"] as! [[String: Any]]
                return ["related": results]
            }
        }

        // Run & report
        await workflow.start()

        // Safely unwrap each output
        let candidates = workflow.outputs["ClassifyIssue.candidates"] as? [Tag] ?? []
        let intentArr = workflow.outputs["ExtractIntent.intent"] as? [[String: Any]] ?? []
        let codesArr = workflow.outputs["TagCodes.codes"] as? [[Tag]] ?? []
        let relatedArr = workflow.outputs["SearchPastIssues.related"] as? [[String: Any]] ?? []

        // Print a concise report
        print("🛠 Issue Triage Report:")
        print("• Candidates:       ", candidates.map { $0.label })
        print("• Primary Intent:   ", intentArr.compactMap { $0["name"] as? String })
        print("• Code/Error tokens:", codesArr.flatMap { $0.map { $0.token } })
        print("• Related issues:   ", relatedArr.map { $0["document"] as! String })
    }
}
