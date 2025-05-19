//
//  ClassificationMLTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/18/25.
//

import XCTest
import NaturalLanguage
@testable import AuroraCore
@testable import AuroraML
@testable import AuroraTaskLibrary

/// A mock classification service that returns a predetermined MLResponse or throws.
private class MockClassificationService: MLServiceProtocol {
    var name: String
    let response: MLResponse
    let shouldThrow: Bool

    init(
        name: String = "mock-classify",
        response: MLResponse = MLResponse(outputs: ["tags": []], info: nil),
        shouldThrow: Bool = false
    ) {
        self.name = name
        self.response = response
        self.shouldThrow = shouldThrow
    }

    func run(request: MLRequest) async throws -> MLResponse {
        if shouldThrow {
            throw NSError(
                domain: name,
                code: 99,
                userInfo: [NSLocalizedDescriptionKey: "forced classification error"]
            )
        }
        return response
    }
}

final class ClassificationMLTaskTests: XCTestCase {

    func testClassificationMLTaskSuccessWithMock() async throws {
        // Given
        let inputs = ["foo", "bar"]
        let tags: [Tag] = [
            Tag(token: "foo", label: "LabelA", scheme: "schemeA", confidence: 0.9, start: 0, length: 3),
            Tag(token: "bar", label: "LabelB", scheme: "schemeA", confidence: 0.8, start: 0, length: 3)
        ]
        let service = MockClassificationService(
            response: MLResponse(outputs: ["tags": tags], info: nil)
        )
        let task = ClassificationMLTask(
            service: service,
            strings: inputs
        )

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        let fetched = outputs["tags"] as? [Tag]
        XCTAssertEqual(fetched?.count, tags.count)
        XCTAssertEqual(fetched?.first?.token, "foo")
        XCTAssertEqual(fetched?.first?.label, "LabelA")
        XCTAssertEqual(fetched?.first?.confidence, 0.9)
    }

    func testClassificationMLTaskEmptyInput() async {
        // Given
        let service = MockClassificationService()
        let task = ClassificationMLTask(service: service)

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }

        // Then
        do {
            _ = try await wrapped.execute()
            XCTFail("Expected error for missing input strings")
        } catch let err as NSError {
            XCTAssertEqual(err.domain, "ClassificationMLTask")
            XCTAssertEqual(err.code, 1)
        }
    }

    func testClassificationMLTaskInputOverride() async throws {
        // Given
        let initial = ["ignore"]
        let override = ["override"]
        let overrideTags: [Tag] = [
            Tag(token: "override", label: "X", scheme: "schemeX", confidence: 1.0, start: 0, length: 8)
        ]
        let service = MockClassificationService(
            response: MLResponse(outputs: ["tags": overrideTags], info: nil)
        )
        let task = ClassificationMLTask(
            service: service,
            strings: initial
        )

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task")
            return
        }
        let outputs = try await wrapped.execute(inputs: ["strings": override])

        // Then
        let fetched = outputs["tags"] as? [Tag]
        XCTAssertEqual(fetched?.count, overrideTags.count)
        XCTAssertEqual(fetched?.first?.token, "override")
        XCTAssertEqual(fetched?.first?.label, "X")
    }

    func testClassificationMLTaskMissingTagsKey() async {
        // Given
        let service = MockClassificationService(
            response: MLResponse(outputs: ["foo": "bar"], info: nil)
        )
        let task = ClassificationMLTask(
            service: service,
            strings: ["test"]
        )

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task")
            return
        }

        // Then
        do {
            _ = try await wrapped.execute()
            XCTFail("Expected error for missing 'tags' in response")
        } catch let err as NSError {
            XCTAssertEqual(err.domain, "ClassificationMLTask")
            XCTAssertEqual(err.code, 2)
        }
    }

    func testClassificationMLTaskServiceErrorPropagates() async {
        // Given
        let service = MockClassificationService(shouldThrow: true)
        let task = ClassificationMLTask(
            service: service,
            strings: ["any"]
        )

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task")
            return
        }

        // Then
        do {
            _ = try await wrapped.execute()
            XCTFail("Expected propagation of service error")
        } catch let err as NSError {
            XCTAssertEqual(err.domain, service.name)
            XCTAssertEqual(err.code, 99)
        }
    }

    func testClassificationMLTaskWithTrivialModel() async throws {
        // Given: trivial classifier that maps "foo" → foo, "bar" → bar
        let url = modelPath(for: "TrivialTextClassifier.mlmodelc")
        guard let nlModel = try? NLModel(contentsOf: url) else {
            throw XCTSkip("Failed to load TrivialTextClassifier model")
        }
        let service = ClassificationService(
            name: "trivial",
            model: nlModel,
            scheme: "test",
            maxResults: 1
        )
        let inputs = ["foo", "bar"]
        let task = ClassificationMLTask(
            service: service,
            strings: inputs
        )

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        let tags = outputs["tags"] as? [Tag]
        XCTAssertEqual(tags?.count, inputs.count)
        XCTAssertEqual(tags?[0].label, "foo")
        XCTAssertEqual(tags?[1].label, "bar")
    }

    func testClassificationMLTaskMissingInputThrows() async {
        // Given
        let url = modelPath(for: "TrivialTextClassifier.mlmodelc")
        guard let nlModel = try? NLModel(contentsOf: url) else {
            XCTFail("Failed to load TrivialTextClassifier model")
            return
        }
        let service = ClassificationService(
            name: "trivial",
            model: nlModel,
            scheme: "test",
            maxResults: 1
        )
        // No fallback strings
        let task = ClassificationMLTask(service: service)

        // When / Then
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task")
            return
        }
        await XCTAssertThrowsErrorAsync(try await wrapped.execute()) { error in
            let ns = error as NSError
            XCTAssertEqual(ns.domain, "ClassificationMLTask")
            XCTAssertEqual(ns.code, 1)
        }
    }

    private func modelPath(for filename: String) -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("models")
            .appendingPathComponent(filename)
    }
}
