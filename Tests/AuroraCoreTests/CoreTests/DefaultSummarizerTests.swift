//
//  DefaultSummarizerTests.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/23/24.
//

import XCTest
@testable import AuroraCore

final class DefaultSummarizerTests: XCTestCase {

    var defaultSummarizer: DefaultSummarizer!

    override func setUp() {
        super.setUp()
        defaultSummarizer = DefaultSummarizer()
    }

    override func tearDown() {
        defaultSummarizer = nil
        super.tearDown()
    }

    func testSingleTextSummarization() {
        // Given
        let text = "This is a simple test text."

        // When
        let summary = defaultSummarizer.summarize(text)

        // Then
        XCTAssertEqual(summary, text, "Default summarizer should return the input text unchanged.")
    }

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
        let expectedSummary = "This is the first sentence. Here comes the second sentence. Finally, the third sentence."
        XCTAssertEqual(summary, expectedSummary, "Default summarizer should concatenate the text of all context items.")
    }

    // Placeholder for future tests when actual summarization logic is added
    func testSummarizationOfLongText() {
        // Given
        let longText = String(repeating: "This is a long text. ", count: 100)

        // When
        let summary = defaultSummarizer.summarize(longText)

        // Then
        // As of now, the summarizer returns the full text. Later, this test can be modified to assert a proper summary.
        XCTAssertEqual(summary, longText, "Default summarizer should return the full text for now.")
    }

    func testSummarizationOfEmptyText() {
        // Given
        let emptyText = ""

        // When
        let summary = defaultSummarizer.summarize(emptyText)

        // Then
        XCTAssertEqual(summary, emptyText, "Summarizer should handle empty text and return it unchanged.")
    }
}
