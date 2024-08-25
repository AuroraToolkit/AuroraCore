//
//  DefaultSummarizer.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/21/24.
//

import Foundation

/**
 The `DefaultSummarizer` class provides a basic implementation of the `Summarizer` protocol.

 It offers general summarization logic for text, code, and articles.
 */
public class DefaultSummarizer: Summarizer {

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
