//
//  PartsOfSpeechWithTaggingTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/8/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraML
@testable import AuroraTaskLibrary

final class PartsOfSpeechWithTaggingTaskTests: XCTestCase {

    func testPOSTaggingWithTaggingTask_MockService() async throws {
        // Given
        let sentence = "Hello world"
        let tagH = Tag(token: "Hello",
                       label: "Interjection",
                       scheme: "mockPOS",
                       confidence: nil,
                       start: 0,
                       length: 5)
        let tagW = Tag(token: "world",
                       label: "Noun",
                       scheme: "mockPOS",
                       confidence: nil,
                       start: 6,
                       length: 5)
        let tags: [[Tag]] = [[tagH, tagW]]
        let mock = MockMLService(
            name: "MockPOS",
            response: MLResponse(outputs: ["tags": tags], info: nil)
        )
        let task = TaggingMLTask(service: mock, strings: [sentence])

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        guard let result = outputs["tags"] as? [[Tag]] else {
            XCTFail("Missing or invalid 'tags'")
            return
        }
        XCTAssertEqual(result, tags)
    }

    func testPOSTaggingWithTaggingTask_TaggingService() async throws {
        // Given
        let sentence = "The quick brown fox jumps."
        let service = TaggingService(
            name: "POSTagger",
            schemes: [.lexicalClass],
            unit: .word
        )
        let task = TaggingMLTask(service: service, strings: [sentence])

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        guard let result = outputs["tags"] as? [[Tag]],
              let tags = result.first else {
            XCTFail("Missing or invalid 'tags'")
            return
        }
        // Expect at least one noun and one verb
        XCTAssertEqual(tags.count, 5)
        XCTAssertTrue(tags.contains { $0.token.lowercased() == "the" && $0.label == "Determiner" })
        XCTAssertTrue(tags.contains { $0.token.lowercased() == "quick" && $0.label == "Adjective" })
        XCTAssertTrue(tags.contains { $0.token.lowercased() == "brown" && $0.label == "Adjective" })
        XCTAssertTrue(tags.contains { $0.token.lowercased() == "fox" && $0.label == "Noun" })
        XCTAssertTrue(tags.contains { $0.token.lowercased() == "jumps" && $0.label == "Verb" })
    }
}
