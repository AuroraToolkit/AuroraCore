//
//  DefaultSummarizerTests.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/23/24.
//

import XCTest
@testable import AuroraCore

final class DefaultSummarizerTests: XCTestCase {

    var defaultSummarizer: Summarizer!

    override func setUp() {
        super.setUp()
        defaultSummarizer = Summarizer()
    }

    override func tearDown() {
        defaultSummarizer = nil
        super.tearDown()
    }

    // MARK: - Text Summarization Tests

    func testSingleTextSummarizationShortText() {
        // Given
        let text = "This is a simple test text."

        // When
        let summary = defaultSummarizer.summarize(text)

        // Then
        XCTAssertEqual(summary, text + "...", "Default summarizer should return the input text with '...' appended if it's short.")
    }

    func testSingleTextSummarizationLongText() {
        // Given
        let longText = String(repeating: "This is a long text. ", count: 10) // This will create a long string

        // When
        let summary = defaultSummarizer.summarize(longText)

        // Then
        let expectedSummary = String(longText.prefix(100)) + "..."
        XCTAssertEqual(summary, expectedSummary, "Default summarizer should truncate the text to 100 characters and append '...'.")
    }

    func testSummarizationOfEmptyText() {
        // Given
        let emptyText = ""

        // When
        let summary = defaultSummarizer.summarize(emptyText)

        // Then
        XCTAssertEqual(summary, "...", "Summarizer should handle empty text by returning just '...'.")
    }

    // MARK: - Multiple Items Summarization Tests

    func testMultipleItemsSummarization() {
        // Given
        let items = [
            ContextItem(text: "This is the first sentence."),
            ContextItem(text: "Here comes the second sentence."),
            ContextItem(text: "Finally, the third sentence.")
        ]

        // When
        let summary = defaultSummarizer.summarizeItems(items)

        // Then
        let expectedSummary = "This is the first sentence. Here comes the second sentence. Finally, the third sentence...."
        XCTAssertEqual(summary, expectedSummary, "Default summarizer should concatenate the text of all context items and truncate to 100 characters.")
    }

    // MARK: - Code Summarization Tests

    func testCodeSummarization() {
        // Given
        let code = """
        func testFunction() {
            print("This is a test.")
        }
        """

        // When
        let summary = defaultSummarizer.summarizeCode(code)

        // Then
        let expectedSummary = String(code.prefix(50)) + "..."
        XCTAssertEqual(summary, expectedSummary, "Default summarizer should truncate the code to 50 characters and append '...'.")
    }

    // MARK: - Article Summarization Tests

    func testArticleSummarization() {
        // Given
        let article = """
        In a recent study, scientists discovered that the earth's core is cooling faster than previously thought.
        This could have significant implications for tectonic activities and climate.
        """

        // When
        let summary = defaultSummarizer.summarizeArticle(article)

        // Then
        let expectedSummary = String(article.prefix(100)) + "..."
        XCTAssertEqual(summary, expectedSummary, "Default summarizer should truncate the article to 100 characters and append '...'.")
    }
}
