//
//  CustomerFeedbackAnalysisWorkflow.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/8/25.
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

        // URL to retrieve app store reviews
        let countryCode = "us"  // Change to your country code if needed
        let appId = "284708449" // Replace with your app ID, e.g. UrbanSpoon app
        let appStoreReviewsURL = "https://itunes.apple.com/\(countryCode)/rss/customerreviews/page=1/id=\(appId)/sortBy=mostRecent/json"

        // Workflow initialization
        var workflow = Workflow(
            name: "Customer Feedback Analysis Workflow",
            description: "Fetch, analyze, and generate insights from app store reviews."
        ) {

            // Step 1: Fetch App Store Reviews
            FetchURLTask(
                name: "FetchReviews",
                url: appStoreReviewsURL
            )

            // Step 2: Parse the reviews feed
            JSONParsingTask(
                name: "ParseReviewsFeed",
                inputs: ["jsonData": "{FetchReviews.data}"]
            )

            // Step 3: Extract Review Text
            Workflow.Task(
                name: "ExtractReviewText",
                inputs: ["parsedJSON": "{ParseReviewsFeed.parsedJSON}"]
            ) { inputs in
                guard let parsedJSON = inputs["parsedJSON"] as? JSONElement,
                let feed = parsedJSON["feed"],
                let entries = feed["entry"]?.asArray else {
                    throw NSError(
                        domain: "CustomerFeedbackAnalysisWorkflow",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "No reviews found in the feed."]
                        )
                }

                // Extract the review text from the JSON feed
                let reviews = entries.compactMap { entry in
                    entry["content"]?["label"]?.asString
                }

                // Limit to 10 reviews for simpler processing
                return ["strings": reviews.prefix(10)]
            }

            // Step 3: Detect Languages of the Reviews
            DetectLanguagesTask(
                name: "DetectReviewLanguages",
                llmService: llmService,
                maxTokens: 1000,
                inputs: ["strings": "{ExtractReviewText.strings}"]
            )

            // Step 4: Analyze Sentiment
            AnalyzeSentimentTask(
                name: "AnalyzeReviewSentiment",
                llmService: llmService,
                detailed: true,
                maxTokens: 1000,
                inputs: ["strings": "{ExtractReviewText.strings}"]
            )

            // Step 5: Extract Keywords from Reviews
            GenerateKeywordsTask(
                name: "ExtractReviewKeywords",
                llmService: llmService,
                maxTokens: 1000,
                inputs: ["strings": "{ExtractReviewText.strings}"]
            )

            // Step 6: Generate Actionable Suggestions
            GenerateTitlesTask(
                name: "GenerateReviewSuggestions",
                llmService: llmService,
                languages: ["en"],
                maxTokens: 1000,
                inputs: ["strings": "{ExtractReviewText.strings}"]
            )

            // Step 7: Summarize Findings
            SummarizeStringsTask(
                name: "SummarizeReviewFindings",
                summarizer: summarizer,
                summaryType: .multiple,
                inputs: ["strings": "{ExtractReviewText.strings}"]
            )
        }

        print("Executing \(workflow.name)...")
        print(workflow.description)

        // Execute the workflow
        await workflow.start()

        // Print the workflow outputs
        if let summaries = workflow.outputs["SummarizeReviewFindings.summaries"] as? [String] {
            print("Review Findings Summaries:")
            summaries.enumerated().forEach { index, summary in
                print("\(index + 1): \(summary)")
            }
        } else {
            print("No summaries generated.")
        }

        // Gather and process additional results
        if let detectedLanguages = workflow.outputs["DetectReviewLanguages.languages"] as? [String: String] {
            let languages = detectedLanguages.values
                .reduce(into: [String: Int]()) { counts, language in
                    counts[language, default: 0] += 1
                }
                .sorted { $0.key < $1.key }
            print("\nLanguages found in reviews:")
            languages.forEach { language, count in
                print("- \(language): \(count) review(s)")
            }
        }

        if let keywordsDict = workflow.outputs["ExtractReviewKeywords.keywords"] as? [String: [String]] {
            let keywords = Set(keywordsDict.values.flatMap { $0 }).sorted()
            print("\nKeywords found in reviews:\n- \(keywords.joined(separator: ", "))")
        }

        // Collect sentiment data
        if let sentiments = workflow.outputs["AnalyzeReviewSentiment.sentiments"] as? [String: [String: Any]] {
            var sentimentCounts = ["Positive": 0, "Neutral": 0, "Negative": 0]
            var sentimentExamples = ["Positive": [String](), "Neutral": [String](), "Negative": [String]()]

            sentiments.forEach { review, sentimentInfo in
                guard
                    let sentiment = sentimentInfo["sentiment"] as? String,
                    let confidence = sentimentInfo["confidence"] as? Int
                else { return }

                sentimentCounts[sentiment, default: 0] += 1

                // Add example review for each sentiment category
                if sentimentExamples[sentiment]?.count ?? 0 < 2 {
                    sentimentExamples[sentiment]?.append("\"\(review)\" (\(confidence)% confidence)")
                }
            }

            // Display sentiment analysis summary
            let totalReviews = sentiments.count
            print("\nOverall sentiment for \(totalReviews) reviews:")
            sentimentCounts.forEach { sentiment, count in
                let percentage = (Double(count) / Double(totalReviews) * 100).rounded()
                print("- \(sentiment): \(Int(percentage))% (\(count) review(s))")
            }

            // Display examples for each sentiment
            print("\nSentiment examples:")
            sentimentExamples.forEach { sentiment, examples in
                print("- \(sentiment):")
                examples.forEach { print("  \(String(describing: $0))") }
            }
        }

        if let suggestions = workflow.outputs["GenerateReviewSuggestions.titles"] as? [String: [String: String]] {
            print("\nActionable Insights:")
            suggestions.forEach { review, titles in
                titles.forEach { _, title in
                    print("Insight: \(title)")
                }
                print("  Based on review: \(review)")
            }
        } else {
            print("No suggestions generated.")
        }
    }
}
