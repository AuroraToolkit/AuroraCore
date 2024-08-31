//
//  SummarizerTests.swift
//
//  Created by Dan Murrell Jr on 8/25/24.
//

import XCTest
@testable import AuroraCore

/**
 Tests for the `Summarizer` protocol and its implementations, including `DefaultSummarizer`, `CodeSummarizer`, and `ArticleSummarizer`.
 */
final class SummarizerTests: XCTestCase {

    func testDefaultSummarizer() {
        // Given
        let summarizer = Summarizer()
        let longText = "This is a long piece of text meant to be summarized. " +
                       "It goes on and on until it reaches the limit of 100 characters."

        // When
        let summary = summarizer.summarize(longText)

        // Then
        let expectedSummary = String(longText.prefix(100)) + "..."
        XCTAssertEqual(summary, expectedSummary, "Default summarizer should truncate text to 100 characters and append '...'.")
    }

    func testCodeSummarizer() {
        // Given
        let summarizer = CodeSummarizer()
        let codeSnippet = """
        func test() {
            print("Hello World")
        }
        """

        // When
        let summary = summarizer.summarizeCode(codeSnippet)

        // Then
        let expectedSummaryPrefix = "Code with 3 lines. First snippet: func test() {\n    print(\"Hello World\")\n}..."
        XCTAssertEqual(summary, expectedSummaryPrefix, "Code summarizer should include descriptive text and the truncated code snippet.")
    }

    func testArticleSummarizer() {
        // Given
        let summarizer = ArticleSummarizer()
        let articleText = "This is the first sentence. This is the second sentence. This is the third sentence. This is the fourth sentence."

        // When
        let summary = summarizer.summarizeArticle(articleText)

        // Then
        let expectedSummary = "This is the first sentence. This is the second sentence. This is the third sentence..."
        XCTAssertEqual(summary, expectedSummary, "Article summarizer should summarize the article to three sentences.")
    }
}
