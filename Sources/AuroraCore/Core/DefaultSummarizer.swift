//
//  DefaultSummarizer.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/21/24.
//

import Foundation

/**
 `DefaultSummarizer` is a concrete implementation of the `Summarizer` protocol.

 This class provides basic summarization functionality, which currently returns the original text without any changes. It can be extended to include more advanced summarization techniques.
 */
public class DefaultSummarizer: Summarizer {

    /**
     Summarizes a single block of text.

     This method currently returns the input text without modification, but it can be extended to implement more complex summarization logic.

     - Parameter text: The input text to be summarized.
     - Returns: The summarized text, which is currently the same as the input.
     */
    public func summarize(_ text: String) -> String {
        // Implement actual summarization logic
        return text
    }

    /**
     Summarizes a collection of `ContextItem` objects by joining their texts.

     This method concatenates the text of multiple `ContextItem` objects and then summarizes the combined text using the `summarize(_:)` method.

     - Parameter items: An array of `ContextItem` objects to be summarized.
     - Returns: The summarized text, which is currently the combined text of all items.
     */
    public func summarizeItems(_ items: [ContextItem]) -> String {
        let text = items.map { $0.text }.joined(separator: " ")
        return summarize(text)
    }
}
