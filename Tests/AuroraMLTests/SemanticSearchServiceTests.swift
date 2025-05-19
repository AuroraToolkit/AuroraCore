//
//  SemanticSearchServiceTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/17/25.
//

import XCTest
@testable import AuroraCore
@testable import AuroraML

final class SemanticSearchServiceTests: XCTestCase {

    /// A tiny MLServiceProtocol mock that returns a fixed embedding for each input string.
    private class MockEmbeddingService: MLServiceProtocol {
        var name: String
        private let mapping: [String: [Double]]
        init(name: String, mapping: [String: [Double]]) {
            self.name = name
            self.mapping = mapping
        }
        func run(request: MLRequest) async throws -> MLResponse {
            guard let texts = request.inputs["strings"] as? [String] else {
                throw NSError(domain: name, code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Missing 'strings'"])
            }
            // Force‐unwrap here for simplicity of the test
            let embeddings: [[Double]] = texts.map { mapping[$0]! }
            return MLResponse(outputs: ["embeddings": embeddings], info: nil)
        }
    }

    func testSemanticSearchWithStringQuery() async throws {
        // Given
        let docs = ["doc1", "doc2", "doc3"]
        let mapping: [String: [Double]] = [
            "doc1": [1, 0],
            "doc2": [0, 1],
            "doc3": [1, 1]
        ]
        let embedSvc = MockEmbeddingService(name: "mock", mapping: mapping)
        let service = SemanticSearchService(
            name: "search",
            embeddingService: embedSvc,
            documents: docs,
            topK: 2
        )

        // When
        let response = try await service.run(
            request: MLRequest(inputs: ["query": "doc1"])
        )

        // Then
        guard let results = response.outputs["results"] as? [[String: Any]] else {
            XCTFail("Missing 'results'")
            return
        }
        XCTAssertEqual(results.count, 2)

        // Best match is "doc1" with cosine == 1.0
        XCTAssertEqual(results[0]["document"] as? String, "doc1")
        let score0 = results[0]["score"] as? Double
        XCTAssertEqual(score0!, 1.0, accuracy: 1e-6)

        // Second-best is "doc3" with cosine([1,0],[1,1]) = √2/2
        XCTAssertEqual(results[1]["document"] as? String, "doc3")
        let score1 = results[1]["score"] as? Double
        let expected = sqrt(2.0) / 2.0
        XCTAssertEqual(score1!, expected, accuracy: 1e-6)
    }

    func testSemanticSearchWithVectorQuery() async throws {
        // Given
        let docs = ["A", "B"]
        let mapping: [String: [Double]] = [
            "A": [1, 0],
            "B": [0, 1]
        ]
        let embedSvc = MockEmbeddingService(name: "mock", mapping: mapping)
        let service = SemanticSearchService(
            name: "search",
            embeddingService: embedSvc,
            documents: docs,
            topK: 1
        )

        // When we supply a raw vector instead of a text query
        let response = try await service.run(
            request: MLRequest(inputs: ["vector": [0.0, 1.0]])
        )

        // Then
        guard let results = response.outputs["results"] as? [[String: Any]] else {
            XCTFail("Missing 'results'")
            return
        }
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0]["document"] as? String, "B")
        let score = results[0]["score"] as? Double
        XCTAssertEqual(score!, 1.0, accuracy: 1e-6)
    }

    func testSemanticSearchMissingInput() async {
        // Given no "query" or "vector" key
        let embedSvc = MockEmbeddingService(name: "mock", mapping: [:])
        let service = SemanticSearchService(
            name: "search",
            embeddingService: embedSvc,
            documents: [],
            topK: 1
        )

        // Then we expect an error about missing input
        await XCTAssertThrowsErrorAsync(try await service.run(request: MLRequest(inputs: [:]))) { error in
            let ns = error as NSError
            XCTAssertEqual(ns.domain, "search")
            XCTAssertEqual(ns.code, 1)
        }
    }
}

// Helper for testing async throws
func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ validate: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {
        validate(error)
    }
}
