//
//  MockSummarizer.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/21/24.
//

import Foundation
@testable import AuroraCore

class MockSummarizer: Summarizer, Equatable {

    func summarizeCode(_ code: String) -> String {
        return "Code Summary"
    }

    func summarizeArticle(_ article: String) -> String {
        return "Article Summary"
    }

    func summarize(_ text: String) -> String {
        return "Summary"
    }

    func summarizeItems(_ items: [ContextItem]) -> String {
        return "Summary of \(items.count) items"
    }

    // Equatable conformance for MockSummarizer
    static func == (lhs: MockSummarizer, rhs: MockSummarizer) -> Bool {
        // Since this is a mock, we can simply return true for equality
        return true
    }
}
