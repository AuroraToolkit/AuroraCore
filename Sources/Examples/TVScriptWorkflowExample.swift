//
//  TVScriptWorkflowExample.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/3/24.
//

import Foundation
import AuroraCore

/**
 Example workflow demonstrating fetching an RSS feed, summarizing articles, and generating a news anchor script using AuroraCore.
 */
struct TVScriptWorkflowExample {
    func execute() async {

        // Set your OpenAI API key as an environment variable to run this example, e.g., `export OPENAI_API_KEY="your-api-key"`
        let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        if openAIKey.isEmpty {
            print("No API key provided. Please set the OPENAI_API_KEY environment variable.")
            return
        }

        // Initialize LLM service
        let openAIService = OpenAIService(apiKey: openAIKey)

        // Workflow initialization
        let workflow = Workflow(
            name: "AP Tech News Script Workflow",
            description: "Fetch and summarize AP Tech News articles for a TV news broadcast."
        )

        // Step 1: Fetch the RSS feed
        let rssFeedURL = URL(string: "http://rsshub.app/apnews/topics/technology")!
        let fetchFeedTask = FetchURLTask(name: "FetchFeed", url: rssFeedURL)
        workflow.addTask(fetchFeedTask)

        // Step 2: Parse the RSS feed
        let parseFeedTask = RSSParsingTask(name: "ParseFeed", feedData: Data())
        workflow.addTask(parseFeedTask)

        // Step 3: Limit the number of articles to a maximum of 10
        let latestArticlesTask = WorkflowTask(
            name: "LatestArticles",
            description: "Limit the number of articles to only the latest 10."
        ) { inputs in
            let articles = inputs["articles"] as? [RSSArticle] ?? []
            return ["latestArticles": Array(articles.prefix(10))]
        }
        workflow.addTask(latestArticlesTask)

        // Step 4: Fetch each article's main details
        let fetchArticlesTask = fetchArticlesTask()
        workflow.addTask(fetchArticlesTask)

        // Step 5: Generate a script for a TV news broadcast where 2-3 anchors read the headlines
        let generateTVScriptTask = WorkflowTask(
            name: "GenerateTVScript",
            description: "Generate a script for a TV news anchor to read the headlines."
        ) { inputs in
            let articleSummaries = inputs["articleSummaries"] as? [String] ?? []
            let combinedSummaries = articleSummaries.map { LLMMessage(role: .user, content: $0) }
            let request = LLMRequest(
                messages: [
                LLMMessage(role: .system, content: """
                    Given the following article headlines and summaries, please generate a script for a team of 
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
                LLMMessage(role: .user, content: "\(combinedSummaries)")
                ],
                maxTokens: 2048
            )
            let task = LLMTask(llmService: openAIService, request: request)
            return try await task.execute()
        }
        workflow.addTask(generateTVScriptTask)

        // Define mappings
        let mappings: WorkflowMappings = [
            "FetchFeed": [:],
            "ParseFeed": [
                "feedData": "FetchFeed.data"
            ],
            "LatestArticles": [
                "articles": "ParseFeed.articles"
            ],
            "FetchArticles": [
                "latestArticles": "LatestArticles.latestArticles"
            ],
            "GenerateTVScript": [
                "articleSummaries": "FetchArticles.articleSummaries"
            ],
        ]

        // Execute the workflow
        let workflowManager = WorkflowManager(workflow: workflow, mappings: mappings)
        await workflowManager.start()

        // Print final output
        if let tvScript = workflowManager.finalOutputs["response"] as? String {
            print("Workflow completed successfully. TV script generated:\n\(tvScript)")
        } else {
            print("Workflow completed, but no TV script was generated.")
        }
    }

    private func fetchArticlesTask() -> WorkflowTask {
        WorkflowTask(
            name: "FetchArticles",
            description: "Fetch and extract the title, summary, and canonical URL of each article."
        ) { inputs in
            // Retrieve articles from inputs
            guard let articles = inputs["latestArticles"] as? [RSSArticle] else {
                throw NSError(domain: "FetchArticles", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid articles input"])
            }

            var summarizedArticles: [String] = []

            // Process each article
            for article in articles {
                // Step 1: Fetch the article content
                let fetchTask = FetchURLTask(url: URL(string: article.link)!)
                let taskOutputs = try await fetchTask.execute()

                guard let data = taskOutputs["data"] as? Data else {
                    throw NSError(domain: "FetchAndSummarizeArticles", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch article content for \(article.link)"])
                }

                guard let rawHTML = String(data: data, encoding: .utf8) else {
                    throw NSError(domain: "FetchAndSummarizeArticles", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to decode article content for \(article.link)"])
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

                // Step 3: Add the summary to the array
                summarizedArticles.append(summary)
            }
            // Output all summaries
            return ["articleSummaries": summarizedArticles]
        }
    }

    private func extractFirstMatch(from text: String, pattern: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex?.firstMatch(in: text, options: [], range: range),
           let resultRange = Range(match.range(at: 1), in: text) {
            return String(text[resultRange])
        }
        return nil
    }
}
