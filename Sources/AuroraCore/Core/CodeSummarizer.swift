//
//  CodeSummarizer.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 8/24/24.
//

import Foundation

/**
 The `CodeSummarizer` class specializes in summarizing blocks of code.

 It provides simple logic to extract information from code, such as the number of lines and a snippet.
 */
public class CodeSummarizer: Summarizer {

    /**
     Summarizes a piece of text by identifying it as code and displaying the number of lines and a snippet.

     - Parameter text: The code to be summarized.
     - Returns: A summary of the code, including line count and a snippet.
     */
    public func summarize(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        return "Code with \(lines.count) lines. First snippet: \(lines.prefix(5).joined(separator: "\n"))..."
    }

    /**
     Summarizes a collection of `ContextItem` objects containing code.

     - Parameter items: An array of `ContextItem` objects representing code.
     - Returns: A summarized version of the code in the context items.
     */
    public func summarizeItems(_ items: [ContextItem]) -> String {
        let combinedCode = items.map { $0.text }.joined(separator: "\n")
        return summarize(combinedCode)
    }

    /**
     Summarizes a block of code by displaying its first few lines.

     - Parameter code: The code to be summarized.
     - Returns: A summarized version of the code snippet.
     */
    public func summarizeCode(_ code: String) -> String {
        return summarize(code)
    }

    /**
     Summarizes an article by indicating that it is not applicable for code summarization.

     - Parameter article: The article to be summarized.
     - Returns: A message indicating that article summarization is not applicable.
     */
    public func summarizeArticle(_ article: String) -> String {
        return "Not applicable for code summarization."
    }
}
