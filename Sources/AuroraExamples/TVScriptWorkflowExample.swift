//
//  TVScriptWorkflowExample.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/3/24.
//

import AuroraCore
import AuroraLLM
import AuroraTaskLibrary
import Foundation

/**
 Example workflow demonstrating fetching an RSS feed, summarizing articles, and generating a news anchor script using AuroraCore.
 */

struct TVScriptWorkflowExample {
    func execute() async {
        // Set your Anthropic API key as an environment variable to run this example, e.g., `export Anthropic_API_KEY="your-api-key"`
        let anthropicAIKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        if anthropicAIKey.isEmpty {
            print("No API key provided. Please set the ANTHROPIC_API_KEY environment variable.")
            return
        }

        // Set your OpenAI API key as an environment variable to run this example, e.g., `export OPENAI_API_KEY="your-api-key"`
        let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        if openAIKey.isEmpty {
            print("No API key provided. Please set the OPENAI_API_KEY environment variable.")
            return
        }
        // Set your Google API key as an environment variable to run this example, e.g., `export GOOGLE_API_KEY="your-api-key"`
        let googleKey = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"] ?? ""
        if googleKey.isEmpty {
            print("No API key provided. Please set the GOOGLE_API_KEY environment variable.")
            return
        }

        // Initialize LLM service, e.g., Anthropic, OpenAI, or Ollama
//        let anthropicService = AnthropicService(apiKey: anthropicAIKey, logger: CustomLogger.shared)
//        let ollamaService = OllamaService(logger: CustomLogger.shared)
//        let openAIService = OpenAIService(apiKey: openAIKey, logger: CustomLogger.shared)
        let googleService = GoogleService(apiKey: googleKey, logger: CustomLogger.shared)

        // Choose which service to use for generating the TV script
        let aiService = googleService

        // Workflow initialization
        var workflow = Workflow(
            name: "AP Tech News Script Workflow",
            description: "Fetch and summarize AP Tech News articles for a TV news broadcast.",
            logger: CustomLogger.shared
        ) {
            // Step 1: Fetch the RSS Feed
            FetchURLTask(name: "FetchFeed", url: "http://rsshub.app/apnews/topics/technology")

            // Step 2: Parse the feed
            RSSParsingTask(name: "ParseFeed", inputs: ["feedData": "{FetchFeed.data}"])

            // Step 3: Limit the number of articles to a maximum of 10
            Workflow.Task(
                name: "LatestArticles",
                inputs: ["articles": "{ParseFeed.articles}"]
            ) { inputs in
                let articles = inputs["articles"] as? [RSSArticle] ?? []
                print("Fetched \(articles.count) articles, limiting to 10.")
                let latestArticles = articles.prefix(10)
                latestArticles.forEach {
                    print("Article: \(String(describing: $0.title)) - \(String(describing: $0.link))")
                }
                return ["articles": Array(latestArticles)]
            }

            // Step 4: Fetch each article's main details
            Workflow.Task(
                name: "FetchArticles",
                description: "Fetch and extract the title, summary, and canonical URL of each article.",
                inputs: ["latestArticles": "{LatestArticles.articles}"]
            ) { inputs in
                guard let articles = inputs["latestArticles"] as? [RSSArticle] else {
                    throw NSError(domain: "FetchArticles", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid articles input"])
                }

                var summarizedArticles: [String] = []
                do {
                    summarizedArticles = try await fetchDetailsFrom(articles)
                } catch {
                    throw NSError(domain: "FetchArticles", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch article details"])
                }

                print("Summarized \(summarizedArticles.count) articles")
                return ["articleSummaries": summarizedArticles]
            }

            // Step 5: Generate a TV news script
            Workflow.Task(
                name: "GenerateTVScript",
                description: "Generate a script for a TV news anchor to read the headlines.",
                inputs: ["articleSummaries": "{FetchArticles.articleSummaries}"]
            ) { inputs in
                let articleSummaries = inputs["articleSummaries"] as? [String] ?? []
                print("Generating TV script from \(articleSummaries.count) articles.")
                let script = try await generateScriptFrom(articleSummaries, llmService: aiService)
                return ["tvScript": script ?? "Failed to generate script."]
            }
        }

        await workflow.start()

        print("Workflow completed successfully.")
        print("TV script generated:\n\(workflow.outputs["GenerateTVScript.tvScript"] as? String ?? "No script generated.")")

        print("\n-------\n")

        let report = await workflow.generateReport()
        print(report.printedReport(compact: true, showOutputs: false))
    }

    private func generateScriptFrom(_ summaries: [String], llmService: LLMServiceProtocol) async throws -> String? {
        let combinedSummaries = summaries.joined(separator: "\n\n")
        let request = LLMRequest(
            messages: [
                LLMMessage(role: .system, content: """
                Given the following article titles, descriptions, and links, please generate a script for a team of
                TV news anchors to read on air. Feel free to rearrange the order to make the script flow better.
                Invent a station identifier similar to KTLA and use a US city of your choice. Remember that stations
                to the west of the Mississippi River uses K callsigns, and stations to the east use W callsigns.

                Come up with two to three anchor full names, and use them in the script. Use friendly TV anchor
                phrases to throw to each one, but each anchor should own an entire story. The script should be
                between 1,000 and 2,000 words. Be sure to come up with a catchy opening line to grab the
                audience's attention. The script should be engaging and informative, using a serious tone when
                appropriate, and a more casual tone for lighter topics. Include typical TV news anchor filler in
                between stories to maintain viewer interest.

                Typically, a TV news broadcast will end with a feel-good story or a humorous anecdote, so pick
                the lightest story to close with, and add a closing line to wrap up the broadcast.
                """),
                LLMMessage(role: .user, content: "\(combinedSummaries)"),
            ],
            maxTokens: 2048
        )
        print("Generating TV script...")
        let task = LLMTask(llmService: llmService, request: request)
        guard case let .task(unwrappedTask) = task.toComponent() else {
            print("Failed to create LLM task.")
            return nil
        }
        let taskOutputs = try await unwrappedTask.execute()
        return taskOutputs["response"] as? String
    }

    private func fetchDetailsFrom(_ articles: [RSSArticle]) async throws -> [String] {
        return try await withThrowingTaskGroup(of: String?.self) { group in
            for article in articles {
                group.addTask {
                    try await fetchDetailsFor(article)
                }
            }
            var summarizedArticles: [String] = []
            for try await summary in group.compactMap({ $0 }) {
                summarizedArticles.append(summary)
            }
            return summarizedArticles
        }
    }

    private func fetchDetailsFor(_ article: RSSArticle) async throws -> String? {
        // Step 1: Fetch the article content
        let fetchTask = FetchURLTask(url: article.link)
        guard case let .task(unwrappedTask) = fetchTask.toComponent() else {
            return nil
        }
        let taskOutputs = try await unwrappedTask.execute()

        guard let data = taskOutputs["data"] as? Data else {
            throw NSError(domain: "FetchAndSummarizeArticles", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch article content for \(article.link) in \(article.title)"])
        }

        guard let rawHTML = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "FetchAndSummarizeArticles", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to decode article content for \(article.link) in \(article.title)"])
        }

        // Step 2: Extract some details from raw HTML of the article
        let titlePattern = "<title>(.*?)</title>"
        let descriptionPattern = "\"description\":\"(.*?)\""
        let canonicalLinkPattern = "<link rel=\"canonical\" href=\"(.*?)\">"

        // Extract data
        let title = extractFirstMatch(from: rawHTML, pattern: titlePattern)
        let description = extractFirstMatch(from: rawHTML, pattern: descriptionPattern)
        let canonicalLink = extractFirstMatch(from: rawHTML, pattern: canonicalLinkPattern)

        let summary = """
        Title: \(title ?? "N/A")
        Description: \(description ?? "N/A")
        Canonical Link: \(canonicalLink ?? "N/A")
        """
        return summary
    }

    private func extractFirstMatch(from text: String, pattern: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        if let match = regex?.firstMatch(in: text, options: [], range: range),
           let resultRange = Range(match.range(at: 1), in: text)
        {
            return String(text[resultRange])
        }
        return nil
    }
}
