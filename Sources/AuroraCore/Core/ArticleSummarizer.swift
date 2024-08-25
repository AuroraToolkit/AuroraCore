//
//  ArticleSummarizer.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 8/24/24.
//

import Foundation

/**
 The `ArticleSummarizer` class specializes in summarizing articles.

 It extracts key sentences to create a concise summary of the article content.
 */
public class ArticleSummarizer: Summarizer {

    /**
     Summarizes an article by extracting the first few key sentences.

     - Parameter text: The article content to be summarized.
     - Returns: A summarized version of the article, consisting of key sentences.
     */
    public func summarize(_ text: String) -> String {
        let sentences = text.components(separatedBy: ". ")
        return sentences.prefix(3).joined(separator: ". ") + "..."
    }

    /**
     Summarizes a collection of `ContextItem` objects as an article.

     - Parameter items: An array of `ContextItem` objects representing an article.
     - Returns: A summarized version of the article content within the context items.
     */
    public func summarizeItems(_ items: [ContextItem]) -> String {
        let combinedText = items.map { $0.text }.joined(separator: ". ")
        return summarize(combinedText)
    }

    /**
     Summarizes a block of code by indicating that it is not applicable for article summarization.

     - Parameter code: The code to be summarized.
     - Returns: A message indicating that code summarization is not applicable.
     */
    public func summarizeCode(_ code: String) -> String {
        return "Not applicable for article summarization."
    }

    /**
     Summarizes an article by extracting key sentences.

     - Parameter article: The article to be summarized.
     - Returns: A concise summary of the article.
     */
    public func summarizeArticle(_ article: String) -> String {
        return summarize(article)
    }
}
