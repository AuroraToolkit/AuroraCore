//
//  MockSummarizer.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/21/24.
//

import Foundation
@testable import AuroraCore

class MockSummarizer: SummarizerProtocol, Equatable {

    func summarize(_ text: String, type: AuroraCore.SummaryType) async throws -> String {
        return "Summary"
    }

    func summarizeGroup(_ texts: [String], type: AuroraCore.SummaryType) async throws -> String {
        return "Summary of \(texts.count) items"
    }

    // Equatable conformance for MockSummarizer
    static func == (lhs: MockSummarizer, rhs: MockSummarizer) -> Bool {
        // Since this is a mock, we can simply return true for equality
        return true
    }
}
