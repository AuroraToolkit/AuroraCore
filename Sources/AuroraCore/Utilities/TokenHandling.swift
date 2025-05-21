//
//  TokenHandling.swift
//
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

public extension String {
    /// Estimates the token count for a given string.
    /// Assumes 1 token per 4 characters as a rough estimation.
    func estimatedTokenCount() -> Int {
        return count / 4
    }

    /**
     Checks if the combined token count of the string and an optional context is within the allowed token limit, considering the buffer.

     - Parameters:
        - context: An optional context string to be combined with the current string.
        - tokenLimit: The maximum allowed token count (default is 1024).
        - buffer: The buffer percentage to reduce the token limit (default is 5%).

     - Returns: A Boolean value indicating whether the combined token count is within the adjusted limit.
     */
    func isWithinTokenLimit(context: String? = nil, tokenLimit: Int = 1024, buffer: Double = 0.05) -> Bool {
        let combinedString = self + (context ?? "")
        let combinedTokenCount = combinedString.estimatedTokenCount()
        let adjustedLimit = Int(floor(Double(tokenLimit) * (1 - buffer)))
        return combinedTokenCount <= adjustedLimit
    }

    /**
     Trims the string according to the specified trimming strategy.

     - Parameters:
        - strategy: The trimming strategy to use (.start, .middle, .end).
        - tokenLimit: The maximum allowed token count after trimming.
        - buffer: A buffer percentage to reduce the maximum token limit.

     - Returns: The trimmed string.
     */
    func trimmedToFit(tokenLimit: Int, buffer: Double = 0.05, strategy: TrimmingStrategy) -> String {
        var trimmedString = self
        let adjustedLimit = Int(Double(tokenLimit) * (1 - buffer))

        while trimmedString.estimatedTokenCount() > adjustedLimit {
            switch strategy {
            case .start:
                trimmedString = String(trimmedString.dropFirst(10))
            case .middle:
                let middleIndex = trimmedString.index(trimmedString.startIndex, offsetBy: trimmedString.count / 2)
                let dropCount = 5
                let firstHalfEndIndex = trimmedString.index(middleIndex, offsetBy: -dropCount)
                let secondHalfStartIndex = trimmedString.index(middleIndex, offsetBy: dropCount)
                trimmedString = String(trimmedString[..<firstHalfEndIndex]) + String(trimmedString[secondHalfStartIndex...])
            case .end:
                trimmedString = String(trimmedString.dropLast(10))
            case .none:
                return self
            }
        }

        return trimmedString
    }

    /// Enum defining trimming strategies.
    enum TrimmingStrategy: CustomStringConvertible {
        case start
        case middle
        case end
        case none

        public var description: String {
            switch self {
            case .start: return "start"
            case .middle: return "middle"
            case .end: return "end"
            case .none: return "none"
            }
        }
    }
}
