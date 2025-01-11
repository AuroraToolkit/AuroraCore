//
//  CustomerFeedbackAnalysisWorkflow.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/4/25.
//

import Foundation
import AuroraCore
import AuroraLLM
import AuroraTaskLibrary

/**
 Example workflow demonstrating fetching customer feedback from an app store,
 analyzing it for insights, and generating actionable suggestions.
 */

struct CustomerFeedbackAnalysisWorkflow {
    func execute() async {

        // Set up the required API key for your LLM service (e.g., OpenAI, Anthropic, or Ollama)
        let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        guard !openAIKey.isEmpty else {
            print("No API key provided. Please set the OPENAI_API_KEY environment variable.")
            return
        }

        // Initialize the LLM service
        let llmService = OpenAIService(apiKey: openAIKey)
        let summarizer = Summarizer(llmService: llmService)

        // Workflow initialization
        var workflow = Workflow(
            name: "Customer Feedback Analysis Workflow",
            description: "Fetch, analyze, and generate insights from app store reviews."
        ) {

            // Step 1: Fetch App Store Reviews
            FetchURLTask(
                name: "FetchReviews",
                url: "https://api.example.com/appstore/reviews?appId=com.example.app"
            )

            // Step 2: Trim Review Text
            TrimmingTask(
                name: "TrimReviews",
                inputs: ["strings": "{FetchReviews.response}"]
            )

            // Step 3: Detect Languages of the Reviews
            DetectLanguagesTask(
                name: "DetectReviewLanguages",
                inputs: ["strings": "{TrimReviews.trimmedStrings}"]
            )

            // Step 4: Analyze Sentiment
            AnalyzeSentimentTask(
                name: "AnalyzeReviewSentiment",
                inputs: ["strings": "{TrimReviews.trimmedStrings}"],
                detailed: true
            )

            // Step 5: Extract Keywords from Reviews
            GenerateKeywordsTask(
                name: "ExtractReviewKeywords",
                inputs: ["strings": "{TrimReviews.trimmedStrings}"]
            )

            // Step 6: Generate Actionable Suggestions
            GenerateTitlesTask(
                name: "GenerateReviewSuggestions",
                inputs: ["strings": "{TrimReviews.trimmedStrings}"],
                languages: ["en"]
            )

            // Step 7: Summarize Findings
            SummarizeStringsTask(
                name: "SummarizeReviewFindings",
                summarizer: summarizer,
                summaryType: .multiple,
                inputs: ["strings": "{TrimReviews.trimmedStrings}"]
            )
        }

        print("Executing \(workflow.name)...")
        print(workflow.description)

        // Execute the workflow
        await workflow.start()

        // Print the workflow outputs
        if let summaries = workflow.outputs["SummarizeReviewFindings.summaries"] as? [String] {
            print("Generated Summaries:\n")
            summaries.enumerated().forEach { index, summary in
                print("\(index + 1): \(summary)")
            }
        } else {
            print("No summaries generated.")
        }

        if let suggestions = workflow.outputs["GenerateReviewSuggestions.titles"] as? [String: [String: String]] {
            print("\nActionable Suggestions:\n")
            suggestions.forEach { review, titles in
                print("Review: \(review)")
                titles.forEach { language, title in
                    print(" - [\(language)]: \(title)")
                }
            }
        } else {
            print("No suggestions generated.")
        }
    }
}