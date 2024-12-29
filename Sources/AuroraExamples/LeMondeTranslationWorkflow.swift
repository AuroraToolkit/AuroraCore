//
//  LeMondeTranslationWorkflow.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 12/29/24.
//

import Foundation
import AuroraCore
import AuroraLLM
import AuroraTaskLibrary

/**
 Example workflow demonstrating fetching news articles from Le Monde, translating them into English,
 and summarizing them using AuroraCore.
 */

struct LeMondeTranslationWorkflow {
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
            name: "Le Monde Translation Workflow",
            description: "Fetch, translate, and summarize articles from Le Monde."
        ) {

            // Step 1: Fetch the Le Monde RSS Feed
            FetchURLTask(name: "FetchLeMondeFeed", url: "https://www.lemonde.fr/international/rss_full.xml")

            // Step 2: Parse the feed
            RSSParsingTask(name: "ParseLeMondeFeed", inputs: ["feedData": "{FetchLeMondeFeed.data}"])

            // Step 3: Limit the number of articles to a maximum of 5
            Workflow.Task(
                name: "LatestArticles",
                inputs: ["articles": "{ParseLeMondeFeed.articles}"]
            ) { inputs in
                let articles = inputs["articles"] as? [RSSArticle] ?? []
                return ["articles": Array(articles.prefix(5))]
            }

            // Step 4: Translate each article into English
            Workflow.Task(
                name: "TranslateArticles",
                inputs: ["latestArticles": "{LatestArticles.articles}"]
            ) { inputs in
                guard let articles = inputs["latestArticles"] as? [RSSArticle] else {
                    throw NSError(domain: "TranslateArticles", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid articles input"])
                }

                var translatedArticles: [String] = []
                let articlesToTranslate = articles.map { $0.description }

                let task = TranslateStringsTask(
                    llmService: llmService,
                    strings: articlesToTranslate,
                    sourceLanguage: "fr",
                    targetLanguage: "en"
                )
                guard case let .task(unwrappedTask) = task.toComponent() else {
                    throw NSError(domain: "TranslateArticles", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create TranslateStringsTask."])
                }

                let outputs = try await unwrappedTask.execute()
                if let translatedStrings = outputs["translatedStrings"] as? [String] {
                    translatedArticles = translatedStrings
                }

                return ["articles": translatedArticles]
            }

            // Step 5: Summarize the translated articles
            SummarizeStringsTask(
                summarizer: summarizer,
                summaryType: .multiple,
                inputs: ["strings": "{TranslateArticles.articles}"]
            )
        }

        print("Executing \(workflow.name)...")
        print(workflow.description)

        // Execute the workflow
        await workflow.start()

        // Print the workflow outputs
        if let summaries = workflow.outputs["SummarizeStringsTask.summaries"] as? [String] {
            print("Generated Summaries:\n")
            summaries.enumerated().forEach { index, summary in
                print("\(index + 1): \(summary)")
            }
        } else {
            print("No summaries generated.")
        }
    }
}
