//
//  DefaultSummarizer.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/21/24.
//

import Foundation

/**
 Enum representing the strategy for summarizing context items.

 - singleItem: Summarizes each item individually.
 - multiItem: Summarizes multiple items together when possible.
 */
public enum SummarizationStrategy {
    case singleItem
    case multiItem
}

/**
 The `SummarizerProtocol` defines a set of methods for summarizing different types of content.

 Summarizers can be customized for general text, code, articles, and context items.
 */
public protocol SummarizerProtocol {

    /**
     Summarizes a given piece of text.

     - Parameter text: The text to be summarized.
     - Returns: A summarized version of the text.
     */
    func summarize(_ text: String) -> String

    /**
     Summarizes a collection of `ContextItem` objects.

     - Parameter items: The `ContextItem` objects to be summarized.
     - Returns: A summarized version of the content within the context items.
     */
    func summarizeItems(_ items: [ContextItem]) -> String

    /**
     Summarizes a block of code.

     - Parameter code: The code to be summarized.
     - Returns: A summarized version of the code.
     */
    func summarizeCode(_ code: String) -> String

    /**
     Summarizes an article.

     - Parameter article: The article content to be summarized.
     - Returns: A summarized version of the article.
     */
    func summarizeArticle(_ article: String) -> String
}

/**
 The `Summarizer` class provides a basic implementation of the `Summarizer` protocol.

 It offers general summarization logic for text, code, and articles.
 */
public class Summarizer: SummarizerProtocol {

    /**
     Summarizes a piece of text by truncating it.

     - Parameter text: The text to be summarized.
     - Returns: A truncated version of the text, followed by ellipsis.
     */
    public func summarize(_ text: String) -> String {
        return String(text.prefix(100)) + "..."
    }

    /**
     Summarizes a collection of `ContextItem` objects by concatenating and truncating their content.

     - Parameter items: An array of `ContextItem` objects.
     - Returns: A summarized version of the concatenated content.
     */
    public func summarizeItems(_ items: [ContextItem]) -> String {
        let combinedText = items.map { $0.text }.joined(separator: " ")
        return summarize(combinedText)
    }

    /**
     Summarizes a block of code by truncating the first few lines.

     - Parameter code: The code to be summarized.
     - Returns: A summarized version of the code snippet.
     */
    public func summarizeCode(_ code: String) -> String {
        return String(code.prefix(50)) + "..."
    }

    /**
     Summarizes an article by truncating it.

     - Parameter article: The article content to be summarized.
     - Returns: A summarized version of the article, followed by ellipsis.
     */
    public func summarizeArticle(_ article: String) -> String {
        return summarize(article)
    }
}
