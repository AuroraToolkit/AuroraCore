//
//  File.swift
//  
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/**
 The `SummarizerProtocol` defines a method for summarizing content via an LLM service.
 */
public protocol SummarizerProtocol {

    /**
     Summarizes a given piece of text using the LLM service.

     - Parameter text: The text to be summarized.
     - Parameter type: The type of summary to be performed (e.g., context, general text, etc.).
     - Returns: A summarized version of the text.
     */
    func summarize(_ text: String, type: SummaryType) async throws -> String
}

/**
 Enum representing different types of summaries that can be requested.
 */
public enum SummaryType {
    case general
    case context
    // Additional types can be added here as needed
}
