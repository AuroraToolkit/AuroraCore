//
//  TokenManager.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/20/24.
//

import Foundation

/**
 A class responsible for managing and enforcing token limits when sending requests to LLMs.

 This class provides methods to estimate token count, check token limits, and trim input content accordingly based on a chosen trimming strategy.
 */
public class TokenManager {

    /// Enumeration defining the trimming strategy to be used when reducing token count.
    public enum TrimmingStrategy {
        /// Trim from the start of the content.
        case start
        /// Trim from the middle of the content.
        case middle
        /// Trim from the end of the content.
        case end
    }

    private let maxTokenLimit: Int  // Maximum allowed token count.
    private let buffer: Double      // Buffer percentage to apply when calculating the token limit.

    /**
     Initializes the `TokenManager` with a maximum token limit and an optional buffer.

     - Parameters:
        - maxTokenLimit: The maximum number of tokens allowed for the content (prompt + context).
        - buffer: A percentage to reduce the maximum token limit by (default is 5%).
     */
    public init(maxTokenLimit: Int, buffer: Double = 0.05) {
        self.maxTokenLimit = maxTokenLimit
        self.buffer = buffer
    }

    /**
     Estimates the token count for a given string.

     - Parameter text: The string for which the token count will be estimated.
     - Returns: The estimated number of tokens in the string.

     This function uses a rough estimation, assuming 1 token per 4 characters.
     */
    public func estimatedTokenCount(for text: String) -> Int {
        return text.count / 4
    }

    /**
     Checks if the combined token count of the prompt and context is within the allowed limit.

     - Parameters:
        - prompt: The text of the prompt.
        - context: The optional context text.
     - Returns: A Boolean value indicating whether the combined token count is within the adjusted limit.
     */
    public func isWithinTokenLimit(prompt: String, context: String?) -> Bool {
        let promptTokens = estimatedTokenCount(for: prompt)
        let contextTokens = estimatedTokenCount(for: context ?? "")

        let adjustedLimit = Int(Double(maxTokenLimit) * (1 - buffer))
        return (promptTokens + contextTokens) <= adjustedLimit
    }

    /**
     Trims the context or prompt to fit within the allowed token limit, based on the selected trimming strategy.

     - Parameters:
        - prompt: The text of the prompt.
        - context: The optional context text.
        - strategy: The trimming strategy to apply (default is `.end`).
     - Returns: A tuple containing the trimmed prompt and context.

     This function will repeatedly trim the context first (or the prompt if the context is nil) until the combined token count is within the allowed limit.
     */
    public func trimToFitTokenLimit(prompt: String, context: String?, strategy: TrimmingStrategy = .end) -> (String, String?) {
        var trimmedPrompt = prompt
        var trimmedContext = context

        while !isWithinTokenLimit(prompt: trimmedPrompt, context: trimmedContext) {
            // Trim context first, then prompt if necessary
            switch strategy {
            case .start:
                if let context = trimmedContext, !context.isEmpty {
                    trimmedContext = String(context.dropFirst(10)) // Trims 10 characters at a time from the start.
                } else {
                    trimmedPrompt = String(trimmedPrompt.dropFirst(10))
                }
            case .middle:
                if let context = trimmedContext, !context.isEmpty {
                    let middleIndex = context.index(context.startIndex, offsetBy: context.count / 2)
                    let dropCount = 5 // Drop 5 characters from each half to make a total of 10
                    let firstHalfEndIndex = context.index(middleIndex, offsetBy: -dropCount)
                    let secondHalfStartIndex = context.index(middleIndex, offsetBy: dropCount)
                    trimmedContext = String(context[..<firstHalfEndIndex]) + String(context[secondHalfStartIndex...])
                } else {
                    let middleIndex = trimmedPrompt.index(trimmedPrompt.startIndex, offsetBy: trimmedPrompt.count / 2)
                    let dropCount = 5 // Drop 5 characters from each half to make a total of 10
                    let firstHalfEndIndex = trimmedPrompt.index(middleIndex, offsetBy: -dropCount)
                    let secondHalfStartIndex = trimmedPrompt.index(middleIndex, offsetBy: dropCount)
                    trimmedPrompt = String(trimmedPrompt[..<firstHalfEndIndex]) + String(trimmedPrompt[secondHalfStartIndex...])
                }
            case .end:
                if let context = trimmedContext, !context.isEmpty {
                    trimmedContext = String(context.dropLast(10)) // Trims 10 characters at a time from the end.
                } else {
                    trimmedPrompt = String(trimmedPrompt.dropLast(10))
                }
            }
        }

        return (trimmedPrompt, trimmedContext)
    }
}
