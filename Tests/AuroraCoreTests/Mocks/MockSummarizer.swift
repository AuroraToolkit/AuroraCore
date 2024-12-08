//
//  MockSummarizer.swift
//  AuroraTests
//
//  Created by Dan Murrell Jr on 8/21/24.
//

import Foundation
@testable import AuroraCore

class MockSummarizer: SummarizerProtocol, Equatable {

    private let expectedSummaries: [String]
    private let expectedResult: Result<[String], Error>

    init(expectedSummaries: [String] = [], expectedResult: Result<[String], Error>? = nil) {
        self.expectedSummaries = expectedSummaries
        self.expectedResult = expectedResult ?? .success(expectedSummaries)
    }

    func summarize(_ text: String, options: SummarizerOptions? = nil) async throws -> String {
        switch expectedResult {
        case .success(let summaries):
            return summaries.first ?? "Summary"
        case .failure(let error):
            throw error
        }
    }

    func summarizeGroup(_ texts: [String], type: SummaryType, options: SummarizerOptions? = nil) async throws -> [String] {
        switch expectedResult {
        case .success(let summaries):
            return summaries
        case .failure(let error):
            throw error
        }
    }

    // Equatable conformance for MockSummarizer
    static func == (lhs: MockSummarizer, rhs: MockSummarizer) -> Bool {
        // Since this is a mock, we can simply return true for equality
        return true
    }
}
