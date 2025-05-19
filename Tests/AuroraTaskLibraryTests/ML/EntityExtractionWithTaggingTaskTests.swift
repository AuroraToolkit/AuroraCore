//
//  EntityExtractionWithTaggingTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/8/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraML
@testable import AuroraTaskLibrary

final class EntityExtractionWithTaggingTaskTests: XCTestCase {

    func testEntityExtractionWithTaggingTask_MockService() async throws {
        // Given
        let texts = ["Alice went to Paris.", "No entities here"]
        let tagA = Tag(token: "Alice",
                       label: "PersonalName",
                       scheme: "mockNER",
                       confidence: nil,
                       start: 0,
                       length: 5)
        let tagP = Tag(token: "Paris",
                       label: "PlaceName",
                       scheme: "mockNER",
                       confidence: nil,
                       start: 11,
                       length: 5)
        let tags: [[Tag]] = [[tagA, tagP], []]
        let mock = MockMLService(
            name: "MockNER",
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

    func testEntityExtractionWithTaggingTask_RealService() async throws {
        // Given
        let texts = ["Alice went to Paris.", "Acme Corp hired Bob."]
        let service = TaggingService(
            name: "NERTagger",
            schemes: [.nameType],
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
        guard let result = outputs["tags"] as? [[Tag]] else {
            XCTFail("Missing or invalid 'tags'")
            return
        }
        // first sentence should tag "Alice" and "Paris"
        XCTAssertTrue(result[0].contains { $0.token == "Alice" && $0.label.contains("Name") })
        XCTAssertTrue(result[0].contains { $0.token == "Paris" && $0.label.contains("Name") })
        // second sentence should tag "Acme Corp" and "Bob"
        XCTAssertTrue(result[1].contains { $0.token == "Acme" && $0.label.contains("OrganizationName") })
        XCTAssertTrue(result[1].contains { $0.token == "Bob" && $0.label.contains("Name") })
    }
}
