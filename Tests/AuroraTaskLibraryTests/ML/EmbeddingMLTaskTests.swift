//
//  EmbeddingMLTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/17/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraML
@testable import AuroraTaskLibrary
import NaturalLanguage

/// A mock embedding service that returns a predetermined set of vectors.
private class MockEmbeddingService: MLServiceProtocol {
    var name: String = "mock-embed"
    let embeddings: [[Double]]
    let shouldThrow: Bool

    init(embeddings: [[Double]], shouldThrow: Bool = false) {
        self.embeddings = embeddings
        self.shouldThrow = shouldThrow
    }

    func run(request: MLRequest) async throws -> MLResponse {
        if shouldThrow {
            throw NSError(domain: name, code: 99,
                          userInfo: [NSLocalizedDescriptionKey: "forced error"])
        }
        return MLResponse(outputs: ["embeddings": embeddings], info: nil)
    }
}

final class EmbeddingMLTaskTests: XCTestCase {

    func testEmbeddingMLTaskSuccessWithMock() async throws {
        // Given
        let inputs = ["a", "b", "c"]
        let fakeVectors: [[Double]] = [
            [1.0, 0.0],
            [0.0, 1.0],
            [0.5, 0.5]
        ]
        let mock = MockEmbeddingService(embeddings: fakeVectors)
        let task = EmbeddingMLTask(
            name: "MockEmbedTask",
            embeddingService: mock,
            strings: inputs
        )

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        let result = outputs["embeddings"] as? [[Double]]
        XCTAssertEqual(result?.count, inputs.count)
        XCTAssertEqual(result, fakeVectors)
    }

    func testEmbeddingMLTaskEmptyInput() async {
        // Given
        let mock = MockEmbeddingService(embeddings: [])
        let task = EmbeddingMLTask(embeddingService: mock)

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task")
            return
        }

        // Then
        do {
            _ = try await wrapped.execute()
            XCTFail("Expected error for empty input")
        } catch let err as NSError {
            XCTAssertEqual(err.domain, "EmbeddingMLTask")
            XCTAssertEqual(err.code, 1)
        }
    }

    func testEmbeddingMLTaskInputOverride() async throws {
        // Given
        let initial = ["x"]
        let override = ["y", "z"]
        let fakeVectors: [[Double]] = [
            [0.1, 0.2, 0.3],
            [0.4, 0.5, 0.6]
        ]
        let mock = MockEmbeddingService(embeddings: fakeVectors)
        let task = EmbeddingMLTask(
            embeddingService: mock,
            strings: initial
        )

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task")
            return
        }
        let outputs = try await wrapped.execute(inputs: ["strings": override])

        // Then
        let result = outputs["embeddings"] as? [[Double]]
        XCTAssertEqual(result?.count, override.count)
        XCTAssertEqual(result, fakeVectors)
    }

    func testEmbeddingMLTaskWithRealSentenceEmbedding() async throws {
        // Given
        guard let embedder = NLEmbedding.sentenceEmbedding(for: .english) else {
            XCTFail("Sentence embedding model unavailable")
            return
        }
        let service = EmbeddingService(
            name: "RealSentenceEmbed",
            embedding: embedder
        )
        let texts = ["Hello world", "Aurora ML"]
        let task = EmbeddingMLTask(
            name: "RealEmbedTask",
            embeddingService: service,
            strings: texts
        )

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        guard let vectors = outputs["embeddings"] as? [[Double]] else {
            XCTFail("Missing 'embeddings' in output")
            return
        }
        XCTAssertEqual(vectors.count, texts.count)
        // Each vector must have the correct dimensionality and non-zero content
        let expectedDim = embedder.dimension
        for vec in vectors {
            XCTAssertEqual(vec.count, expectedDim)
            XCTAssertTrue(vec.contains { abs($0) > 1e-6 },
                          "Expected non-zero values in embedding vector")
        }
    }
}
