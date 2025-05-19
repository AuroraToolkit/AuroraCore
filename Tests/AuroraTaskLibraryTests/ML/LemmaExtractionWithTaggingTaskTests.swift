//
//  LemmaExtractionWithTaggingTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/8/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraML
@testable import AuroraTaskLibrary

final class LemmaExtractionWithTaggingTaskTests: XCTestCase {

    func testLemmaExtractionWithTaggingTask_MockService() async throws {
        // Given
        let texts = ["running", "dogs"]
        let tag1 = Tag(token: "running",
                       label: "run",
                       scheme: "mockLemma",
                       confidence: nil,
                       start: 0,
                       length: 7)
        let tag2 = Tag(token: "dogs",
                       label: "dog",
                       scheme: "mockLemma",
                       confidence: nil,
                       start: 0,
                       length: 4)
        let tags: [[Tag]] = [[tag1], [tag2]]
        let mock = MockMLService(
            name: "MockLemmaService",
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
        guard let result = outputs["tags"] as? [[Tag]] else {
            XCTFail("Missing or invalid 'tags'")
            return
        }
        XCTAssertEqual(result, tags)
    }

    func testLemmaExtractionWithTaggingTask_TaggingService() async throws {
        // Given
        let texts = ["running", "went", "seeing", "children", "took"]
        let service = TaggingService(
            name: "LemmaTagger",
            schemes: [.lemma],
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
        guard let tagArrays = outputs["tags"] as? [[Tag]] else {
          XCTFail("Missing or invalid 'tags'")
            return
        }

        // Flatten across all input strings
        let tags = tagArrays.flatMap { $0 }

        XCTAssertEqual(tags.count, 5)
        XCTAssertTrue(tags.contains { $0.token.lowercased() == "running" && $0.label == "run" })
        XCTAssertTrue(tags.contains { $0.token.lowercased() == "went" && $0.label == "go" })
        XCTAssertTrue(tags.contains { $0.token.lowercased() == "seeing" && $0.label == "see" })
        XCTAssertTrue(tags.contains { $0.token.lowercased() == "children" && $0.label == "child" })
        XCTAssertTrue(tags.contains { $0.token.lowercased() == "took" && $0.label == "take" })
    }
}
