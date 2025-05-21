//
//  SupportTicketWorkflowExample.swift
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
 Example workflow demonstrating multi‐step support‐ticket analysis:

 1. Classify ticket type with a Core ML text classifier
 2. Extract the user’s intent via IntentExtractionMLTask
 3. Run a semantic search against a static FAQ corpus
 4. Tag named entities in the ticket

 The final report prints:
 • Predicted ticket types
 • Extracted intent(s)
 • Top-K FAQ hits
 • Recognized entities
 */
struct SupportTicketWorkflowExample {
    func execute(on ticketText: String) async {
        print("🔍 Analyzing support ticket...")
        print("• Ticket text: \(ticketText)\n")

        // Load your ticket‐type classifier (replace with your real model)
        let modelsDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("models")
        let classifierURL = modelsDir.appendingPathComponent("SupportTicketsClassifier.mlmodelc")
        guard let classifierModel = try? NLModel(contentsOf: classifierURL) else {
            print("❌ Could not load SupportTicketsClassifier.mlmodelc")
            return
        }
        let classificationService = ClassificationService(
            name: "TicketClassifier",
            model: classifierModel,
            scheme: "ticketType",
            maxResults: 2,
            logger: CustomLogger.shared
        )

        // Prepare intent‐extraction (using the same trivial classifier for demo)
        let intentService = IntentExtractionService(
            model: classifierModel,
            maxResults: 1,
            logger: CustomLogger.shared
        )

        // Build FAQ semantic‐search over a small corpus
        let faqs = [
            // billing_issue
            "Why was I charged twice this month?",
            "How can I update my credit card on file?",

            // bug_report
            "The app crashes when I tap the upload button.",
            "Search results always come back empty.",

            // feature_request
            "Can you add dark mode to the app?",
            "Please allow exporting reports as CSV.",

            // login_issue
            "Why was my account locked?",
            "How do I reset my password?",

            // password_reset
            "I never received the password reset email.",
            "The reset link keeps expiring.",

            // account_closure
            "How do I permanently delete my account?",
            "Please cancel my subscription and close my profile.",
        ]
        guard let embedModel = NLEmbedding.sentenceEmbedding(for: .english) else {
            print("❌ Sentence embedding unavailable")
            return
        }
        let embeddingService = EmbeddingService(
            name: "SentenceEmbedding",
            embedding: embedModel,
            logger: CustomLogger.shared
        )
        let faqSearchService = SemanticSearchService(
            name: "FAQSearch",
            embeddingService: embeddingService,
            documents: faqs,
            topK: 2,
            logger: CustomLogger.shared
        )

        // Initialize your NER tagging service
        // (Replace with your real TaggingService init)
        let taggingService = TaggingService(
            name: "NERService",
            schemes: [.nameType],
            logger: CustomLogger.shared
        )

        // Build and run the workflow
        var workflow = Workflow(
            name: "SupportTicketAnalysis",
            description: "Classify, extract intent, search FAQs, and tag entities"
        ) {
            // Classification
            Workflow.Task(
                name: "ClassifyTicket",
                inputs: ["text": ticketText]
            ) { inputs in
                let text = inputs["text"] as! String
                let resp = try await classificationService.run(
                    request: MLRequest(inputs: ["strings": [text]])
                )
                let tags = resp.outputs["tags"] as! [Tag]
                return ["ticketTypes": tags]
            }

            // Intent extraction
            Workflow.Task(
                name: "ExtractIntent",
                inputs: ["text": ticketText]
            ) { inputs in
                let text = inputs["text"] as! String
                let resp = try await intentService.run(
                    request: MLRequest(inputs: ["strings": [text]])
                )
                let intents = resp.outputs["intents"] as! [[String: Any]]
                return ["intents": intents]
            }

            // FAQ semantic search
            Workflow.Task(
                name: "SearchFAQs",
                inputs: ["query": ticketText]
            ) { inputs in
                let query = inputs["query"] as! String
                let resp = try await faqSearchService.run(
                    request: MLRequest(inputs: ["query": query])
                )
                let results = resp.outputs["results"] as! [[String: Any]]
                return ["faqHits": results]
            }

            // Named‐entity tagging
            Workflow.Task(
                name: "TagEntities",
                inputs: ["strings": [ticketText]]
            ) { inputs in
                let texts = inputs["strings"] as! [String]
                let resp = try await taggingService.run(
                    request: MLRequest(inputs: ["strings": texts])
                )
                let entityLists = resp.outputs["tags"] as! [[Tag]]
                return ["entities": entityLists]
            }
        }

        await workflow.start()

        // Gather and print results
        let types = workflow.outputs["ClassifyTicket.ticketTypes"] as? [Tag] ?? []
        let intents = workflow.outputs["ExtractIntent.intents"] as? [[String: Any]] ?? []
        let faqsOut = workflow.outputs["SearchFAQs.faqHits"] as? [[String: Any]] ?? []
        let entities = workflow.outputs["TagEntities.entities"] as? [[Tag]] ?? []

        print("🛎 Support Ticket Report")
        print("• Ticket Types: ", types.map(\.label))
        print("• Intents:      ", intents.map { $0["name"] as! String })
        print("• Top FAQs:     ", faqsOut.map { $0["document"] as! String })
        print("• Entities:     ", entities)

        // Optional: full workflow report
        let fullReport = await workflow.generateReport()
        print(fullReport.printedReport(compact: true, showOutputs: false))
    }
}
