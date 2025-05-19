//
//  EmbeddingServiceTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/17/25.
//

import XCTest
import NaturalLanguage
@testable import AuroraML
@testable import AuroraCore

final class EmbeddingServiceTests: XCTestCase {

    /// Tests that the service returns one vector per input string,
    /// each of the correct dimensionality and non‐zero.
    func testEmbeddingServiceSuccess() async throws {
        // Choose a real Apple embedding model (sentence or word) if available.
        let embedder = NLEmbedding.sentenceEmbedding(for: .english)
            ?? NLEmbedding.wordEmbedding(for: .english)
        guard let embedding = embedder else {
            throw XCTSkip("No English embedding available on this platform")
        }

        let service = EmbeddingService(name: "TestEmbedding", embedding: embedding)
        let texts = ["Hello world", "Quick brown fox"]
        let request = MLRequest(inputs: ["strings": texts])
        let response = try await service.run(request: request)

        guard let vectors = response.outputs["embeddings"] as? [[Double]] else {
            XCTFail("Missing or invalid 'embeddings' output")
            return
        }

        // Should get one vector per input
        XCTAssertEqual(vectors.count, texts.count)

        for vec in vectors {
            // Each vector should match the model's dimension
            XCTAssertEqual(vec.count, embedding.dimension)
            // And not be all zeros
            XCTAssertTrue(vec.contains { abs($0) > 1e-6 },  // guard against floating-point precision issues
                          "Expected non-zero values in embedding vector")
        }
    }

    /// Tests that the service throws the proper error when no "strings" input is provided.
    func testEmbeddingServiceMissingInput() async throws {
        // Use any available embedding
        let wordEmbedding = NLEmbedding.wordEmbedding(for: .english)
        guard let embedding = wordEmbedding else {
            throw XCTSkip("No English word embedding available on this platform")
        }

        let service = EmbeddingService(name: "TestEmbedding", embedding: embedding)
        let request = MLRequest(inputs: [:])  // no "strings" key

        do {
            _ = try await service.run(request: request)
            XCTFail("Expected error for missing 'strings' input")
        } catch {
            let ns = error as NSError
            XCTAssertEqual(ns.domain, "TestEmbedding")
            XCTAssertEqual(ns.code, 1)
        }
    }
}
