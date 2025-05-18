//
//  SemanticSearchMLTaskTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/17/25.
//

import XCTest
import NaturalLanguage
@testable import AuroraCore
@testable import AuroraML
@testable import AuroraTaskLibrary

/// A mock ML service that returns a fixed results array.
private class MockSemanticSearchService: MLServiceProtocol {
    var name: String
    let response: MLResponse
    init(name: String, response: MLResponse = MLResponse(outputs: ["results": []], info: nil)) {
        self.name = name
        self.response = response
    }
    func run(request: MLRequest) async throws -> MLResponse {
        return response
    }
}

final class SemanticSearchMLTaskTests: XCTestCase {

    func testSemanticSearchMLTaskWithQuery() async throws {
        // Given
        let results: [[String: Any]] = [
            ["document": "doc1", "score": 0.9],
            ["document": "doc2", "score": 0.8]
        ]
        let service = MockSemanticSearchService(
            name: "search-mock",
            response: MLResponse(outputs: ["results": results], info: nil)
        )
        let task = SemanticSearchMLTask(
            service: service,
            query: "test query"
        )

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        let fetched = outputs["results"] as? [[String: Any]]
        XCTAssertEqual(fetched?.count, results.count)
        XCTAssertEqual(fetched?.first?["document"] as? String, "doc1")
        XCTAssertEqual(fetched?.first?["score"] as? Double, 0.9)
    }

    func testSemanticSearchMLTaskWithVector() async throws {
        // Given
        let vector: [Double] = [1.0, 2.0, 3.0]
        let results: [[String: Any]] = [
            ["document": "docA", "score": 0.7],
            ["document": "docB", "score": 0.6]
        ]
        let service = MockSemanticSearchService(
            name: "search-mock",
            response: MLResponse(outputs: ["results": results], info: nil)
        )
        let task = SemanticSearchMLTask(
            service: service,
            vector: vector
        )

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute()

        // Then
        let fetched = outputs["results"] as? [[String: Any]]
        XCTAssertEqual(fetched?.count, results.count)
        XCTAssertEqual(fetched?[1]["document"] as? String, "docB")
        XCTAssertEqual(fetched?[1]["score"] as? Double, 0.6)
    }

    func testSemanticSearchMLTaskMissingInput() async {
        // Given
        let service = MockSemanticSearchService(name: "search-mock")
        let task = SemanticSearchMLTask(service: service)

        // When / Then
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }

        await XCTAssertThrowsErrorAsync(try await wrapped.execute()) { error in
            let ns = error as NSError
            XCTAssertEqual(ns.domain, "SemanticSearchMLTask")
            XCTAssertEqual(ns.code, 1)
        }
    }

    func testSemanticSearchMLTaskMissingResultsKey() async {
        // Given
        let badResponse = MLResponse(outputs: ["foo": "bar"], info: nil)
        let service = MockSemanticSearchService(
            name: "search-mock",
            response: badResponse
        )
        let task = SemanticSearchMLTask(service: service, query: "irrelevant")

        // When / Then
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }

        await XCTAssertThrowsErrorAsync(try await wrapped.execute()) { error in
            let ns = error as NSError
            XCTAssertEqual(ns.domain, "SemanticSearchMLTask")
            XCTAssertEqual(ns.code, 2)
            XCTAssertTrue(ns.localizedDescription.contains("Missing 'results'"))
        }
    }

    func testSemanticSearchMLTaskWithDynamicInputOverride() async throws {
        // Given
        let results: [[String: Any]] = [
            ["document": "dynDoc", "score": 0.5]
        ]
        let service = MockSemanticSearchService(
            name: "search-mock",
            response: MLResponse(outputs: ["results": results], info: nil)
        )
        // No fallback query/vector
        let task = SemanticSearchMLTask(service: service)

        // When
        guard case let .task(wrapped) = task.toComponent() else {
            XCTFail("Failed to unwrap Workflow.Task.")
            return
        }
        let outputs = try await wrapped.execute(inputs: ["query": "override"])

        // Then
        let fetched = outputs["results"] as? [[String: Any]]
        XCTAssertEqual(fetched?.first?["document"] as? String, "dynDoc")
    }

    func testSemanticSearchServiceWithQueryReturnsExpectedTopHit() async throws {
        // Arrange
        let docs = [
            "The cat sat on the mat",
            "A quick brown fox jumped over the lazy dog",
            "An apple a day keeps the doctor away"
        ]

        // load the built-in sentence embedding for English
        guard let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english) else {
            // Skip if the embedding model isn’t available in this environment
            XCTFail("NLEmbedding.sentenceEmbedding(for: .english) unavailable")
            return
        }

        let embeddingService = EmbeddingService(
            name: "SentenceEmbedding",
            embedding: sentenceEmbedding
        )

        // only care about the top 2 results
        let searchService = SemanticSearchService(
            name: "IntegrationSearch",
            embeddingService: embeddingService,
            documents: docs,
            topK: 2
        )

        // Act
        let resp = try await searchService.run(
            request: MLRequest(inputs: ["query": "fast fox"])
        )

        // Assert
        guard let results = resp.outputs["results"] as? [[String: Any]],
              results.count == 2 else {
            XCTFail("Expected 2 results, got: \(resp.outputs)")
            return
        }

        // The second document (“quick brown fox”) should score highest for “fast fox”
        XCTAssertEqual(
            results[0]["document"] as? String,
            docs[1],
            "Top hit should be the fox sentence"
        )

        // And its similarity should exceed the next result’s score
        let topScore = results[0]["score"] as! Double
        let nextScore = results[1]["score"] as! Double
        XCTAssertTrue(
            topScore > nextScore,
            "Top score (\(topScore)) should be greater than next (\(nextScore))"
        )
    }

    func testSemanticSearchServiceWithVectorInputMatchesQueryFlow() async throws {
        // Arrange
        let docs = ["red car", "blue bicycle", "fast fox"]
        guard let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english) else {
            XCTFail("Embedding model unavailable")
            return
        }
        let embeddingService = EmbeddingService(
            name: "SentenceEmbedding",
            embedding: sentenceEmbedding
        )
        let searchService = SemanticSearchService(
            name: "IntegrationSearch",
            embeddingService: embeddingService,
            documents: docs,
            topK: 1
        )

        // First generate an embedding vector for “fast fox”
        let queryResp = try await embeddingService.run(
            request: MLRequest(inputs: ["strings": ["fast fox"]])
        )
        guard let vec = (queryResp.outputs["embeddings"] as? [[Double]])?.first else {
            XCTFail("Failed to embed the query string")
            return
        }

        // Act
        let resp = try await searchService.run(
            request: MLRequest(inputs: ["vector": vec])
        )

        // Assert
        guard let results = resp.outputs["results"] as? [[String: Any]],
              let hit = results.first?["document"] as? String else {
            XCTFail("Unexpected response: \(resp.outputs)")
            return
        }

        XCTAssertEqual(
            hit,
            "fast fox",
            "Using the raw embedding vector should still return the correct top document"
        )
    }
}
