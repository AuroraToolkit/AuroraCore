//
//  SummarizerProtocol.swift
//
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/**
 The `SummarizerProtocol` defines methods for summarizing content via an LLM service.
 */
public protocol SummarizerProtocol {
    /**
     Summarizes text using the LLM service.

     - Parameters:
        - text: The text to be summarized.
        - options: Optional `SummarizerOptions` to modify the request parameters.

     - Returns: A summarized version of the text.
     */
    func summarize(_ text: String, options: SummarizerOptions?) async throws -> String

    /**
     Summarizes a group of text strings using the LLM service.

     - Parameters:
        - texts: An array of strings to be summarized.
        - type: The type of summary to be performed (`.single` or `.multiple`).
        - options: Optional `SummarizerOptions` to modify the request parameters.

     - Returns: An array of summarized texts corresponding to the input texts.

     - Note: If `type` is `.single`, the return value will be an array of one summary.
     */
    func summarizeGroup(_ texts: [String], type: SummaryType, options: SummarizerOptions?) async throws -> [String]
}

/**
 Enum representing different types of summaries that can be requested.
 */
public enum SummaryType {
    case single // A single, combined summary for all input strings
    case multiple // Individual summaries for each input string
}
