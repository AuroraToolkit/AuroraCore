//
//  Summarizer.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 8/24/24.
//

import Foundation

/**
 The `Summarizer` protocol defines a set of methods for summarizing different types of content.

 Summarizers can be customized for general text, code, articles, and context items.
 */
public protocol Summarizer {

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
