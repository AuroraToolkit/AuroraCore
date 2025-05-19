//
//  KeywordExtractionWithTaggingTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/8/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraML
@testable import AuroraTaskLibrary

final class KeywordExtractionWithTaggingTaskTests: XCTestCase {

    func testKeywordExtractionWithTaggingTask_MockService() async throws {
        // Given
        let texts = ["Alpha Beta skip"]
        // Mock lemma tags
        let tagAlphaLemma = Tag(token: "Alpha",
                                label: "alpha",
                                scheme: "mockLemma",
                                confidence: nil,
                                start: 0,
                                length: 5)
        let tagBetaLemma  = Tag(token: "Beta",
                                label: "beta",
                                scheme: "mockLemma",
                                confidence: nil,
                                start: 6,
                                length: 4)
        let tagSkipLemma  = Tag(token: "skip",
                                label: "skip",
                                scheme: "mockLemma",
                                confidence: nil,
                                start: 11,
                                length: 4)
        // Mock POS tags
        let tagAlphaPOS = Tag(token: "Alpha",
                              label: "ProperNoun",
                              scheme: "mockPOS",
                              confidence: nil,
                              start: 0,
                              length: 5)
        let tagBetaPOS  = Tag(token: "Beta",
                              label: "Noun",
                              scheme: "mockPOS",
                              confidence: nil,
                              start: 6,
                              length: 4)
        let tagSkipPOS  = Tag(token: "skip",
                              label: "Other",
                              scheme: "mockPOS",
                              confidence: nil,
                              start: 11,
                              length: 4)

        // Mock service returns both lemma+POS tags
        let tags: [[Tag]] = [[
            tagAlphaLemma, tagAlphaPOS,
            tagBetaLemma, tagBetaPOS,
            tagSkipLemma, tagSkipPOS
        ]]
        let mock = MockMLService(
            name: "MockKeywordService",
            response: MLResponse(outputs: ["tags": tags], info: nil)
        )
        let task = TaggingMLTask(service: mock, strings: texts)

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        guard let result = outputs["tags"] as? [[Tag]],
              let flat = result.first else {
            XCTFail("Missing or invalid 'tags'")
            return
        }

        // Build a map from token → lemma
        var lemmaMap = [String: String]()
        for tag in flat where tag.scheme == "mockLemma" {
            lemmaMap[tag.token] = tag.label
        }

        // Keep only ProperNoun/Noun tokens and map to their lemma
        let keywords = flat
            .filter { $0.scheme == "mockPOS" && ["ProperNoun", "Noun"].contains($0.label) }
            .compactMap { lemmaMap[$0.token]?.lowercased() }

        XCTAssertEqual(Set(keywords), Set(["alpha", "beta"]))
        XCTAssertFalse(keywords.contains("skip"))
    }

    func testKeywordExtractionWithTaggingTask_TaggingService() async throws {
        // Given
        let texts = [
            "OpenAI releases GPT-5 update.",
            "AuroraToolkit simplifies development."
        ]
        let service = TaggingService(
            name: "KeywordTagger",
            schemes: [.lemma, .lexicalClass],   // use multiple schemes
            unit: .word
        )
        let task = TaggingMLTask(service: service, strings: texts)

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        guard let resultGroups = outputs["tags"] as? [[Tag]], resultGroups.count == 2 else {
            XCTFail("Missing or invalid 'tags' for both sentences")
            return
        }

        // First sentence keywords
        let keywords1 = extractKeywords(from: resultGroups[0])
        XCTAssertEqual(Set(keywords1), Set(["openai", "update", "release"]))

        // Second sentence keywords
        let keywords2 = extractKeywords(from: resultGroups[1])
        XCTAssertEqual(Set(keywords2), Set(["simplify", "development"]))
    }

    // Helper to extract keywords from a flat Tag array
    private func extractKeywords(from flat: [Tag]) -> [String] {
        // build lemma map
        var lemmaMap = [String: String]()
        for tag in flat where tag.scheme.lowercased() == "lemma" {
            lemmaMap[tag.token] = tag.label.lowercased()
        }
        // filter Noun/ProperNoun and map via lemma or raw token
        return flat
            .filter {
                $0.scheme.lowercased() == "lexicalclass" &&
                ["Noun", "ProperNoun"].contains($0.label)
            }
            .compactMap { lemmaMap[$0.token] }
    }

}
