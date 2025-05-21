//
//  ContextItem.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/20/24.
//

import Foundation

/**
 A representation of an individual item within a context. Each `ContextItem` has text content,
 a creation date, a flag indicating whether it is a summary, and an estimated token count.

 `ContextItem`s are uniquely identified by their `UUID` and can be checked for age and equality.
 */
public struct ContextItem: Identifiable, Codable, Equatable {
    /// Unique identifier for the `ContextItem`.
    public let id: UUID

    /// The text content of the `ContextItem`.
    public var text: String

    /// The date the `ContextItem` was created.
    public var creationDate: Date

    /// A flag indicating whether the `ContextItem` is a summary.
    public var isSummarized: Bool

    /// The estimated token count for the text content of the `ContextItem`.
    public var tokenCount: Int

    /**
     Initializes a new `ContextItem` with the specified text content and optional parameters for creation date and summary status.

     - Parameters:
        - text: The text content of the `ContextItem`.
        - creationDate: The date the item was created (default is the current date).
        - isSummary: A flag indicating whether the item is a summary (default is `false`).
     */
    public init(text: String, creationDate: Date = Date(), isSummary: Bool = false) {
        id = UUID()
        self.text = text
        self.creationDate = creationDate
        isSummarized = isSummary
        // Calculate token count after initializing all properties
        tokenCount = ContextItem.estimateTokenCount(for: text)
    }

    /**
     Helper method to estimate the token count for a given text.

     This is a rough estimate that assumes 1 token per 4 characters (on average).

     - Parameter text: The text content to estimate token count for.

     - Returns: The estimated number of tokens.
     */
    public static func estimateTokenCount(for text: String) -> Int {
        // Rough estimate: 1 token per 4 characters (average)
        return text.count / 4
    }

    /**
     Checks if the `ContextItem` is older than a specified number of days.

     - Parameter days: The number of days to compare against.

     - Returns: `true` if the item is older than the specified number of days, otherwise `false`.
     */
    public func isOlderThan(days: Int) -> Bool {
        guard let daysAgo = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return false
        }
        return creationDate < daysAgo
    }

    /**
     Conformance to `Equatable` for comparison between `ContextItem`s.

     - Parameters:
        - lhs: The left-hand side `ContextItem` to compare.
        - rhs: The right-hand side `ContextItem` to compare.

     - Returns: `true` if the `ContextItem`s are equal, otherwise `false`.
     */
    public static func == (lhs: ContextItem, rhs: ContextItem) -> Bool {
        return lhs.id == rhs.id &&
            lhs.text == rhs.text &&
            lhs.creationDate == rhs.creationDate &&
            lhs.isSummarized == rhs.isSummarized &&
            lhs.tokenCount == rhs.tokenCount
    }
}
