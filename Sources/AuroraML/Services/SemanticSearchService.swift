//
//  SemanticSearchService.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/17/25.
//

import AuroraCore
import Foundation
import NaturalLanguage

/**
 A simple in-memory semantic search over a static document set, using any `MLServiceProtocol`
 that emits `[[Double]]` embeddings under the `"embeddings"` key.

 - **Inputs**
    - `query`: `String` to search for, **or**
    - `vector`: `[Double]` raw embedding to search with.
 - **Outputs**
    - `results`: `[[String: Any]]` — an array of `"document"`: `String`
    - `"score"`: `Double` (cosine similarity)

 ### Example
 ```swift
 let docs = ["The cat sat", "A quick brown fox"]
 // load the built-in sentence embedding for English
 guard let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english) else {
    fatalError("Embedding model unavailable")
 }
 let embeddingService = EmbeddingService(
    name: "SentenceEmbedding",
    embedding: sentenceEmbedding
 )
 let searchService = SemanticSearchService(
    name: "DemoSearch",
    embeddingService: embeddingService,
    documents: docs,
    topK: 1
 )
 let resp = try await searchService.run(
 request: MLRequest(inputs: ["query": "fast fox"])
 )
 let hits = resp.outputs["results"] as! [[String: Any]]
 // hits[0]["document"] == "A quick brown fox"

 */
public final class SemanticSearchService: MLServiceProtocol {
    public var name: String
    private let embeddingService: MLServiceProtocol
    private let documents: [String]
    private let topK: Int
    private let logger: CustomLogger?

    private struct ScoredDocument {
        let document: String
        let score: Double
    }

    /**
     - Parameters:
        - name: Identifier for this service.
        - embeddingService: Any service that implements `MLServiceProtocol` and returns `[[Double]]` under `"embeddings"`.
        - documents: The corpus of texts to search.
        - topK: How many top results to return (default: 5).
        - logger: Optional logger for debugging.
     */
    public init(
        name: String,
        embeddingService: MLServiceProtocol,
        documents: [String],
        topK: Int = 5,
        logger: CustomLogger? = nil
    ) {
        self.name = name
        self.embeddingService = embeddingService
        self.documents = documents
        self.topK = topK
        self.logger = logger
    }

    public func run(request: MLRequest) async throws -> MLResponse {
        /// Ensure the embedding service is available and run it using the provided documents to embed the corpus.
        let docsResp = try await embeddingService.run(
            request: MLRequest(inputs: ["strings": documents])
        )
        /// Extract the document vectors from the response.
        guard let docVectors = docsResp.outputs["embeddings"] as? [[Double]] else {
            logger?.error("Missing 'embeddings' for documents", category: name)
            throw NSError(
                domain: name,
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing 'embeddings' for documents"]
            )
        }

        /// Resolve the query or vector fallback.
        let qVec: [Double]
        if let query = request.inputs["query"] as? String {
            let qResp = try await embeddingService.run(
                request: MLRequest(inputs: ["strings": [query]])
            )
            guard let first = (qResp.outputs["embeddings"] as? [[Double]])?.first else {
                logger?.error("Missing 'embeddings' for query", category: name)
                throw NSError(
                    domain: name,
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Missing 'embeddings' for query"]
                )
            }
            qVec = first
        } else if let raw = request.inputs["vector"] as? [Double] {
            qVec = raw
        } else {
            logger?.error("Input 'query' or 'vector' missing", category: name)
            throw NSError(
                domain: name,
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Input 'query' or 'vector' missing"]
            )
        }

        /// Compute cosine similarity between two vectors  (e.g. query and document).
        func cosine(_ a: [Double], _ b: [Double]) -> Double {
            let dot = zip(a, b).map(*).reduce(0, +)
            let magA = sqrt(a.map { $0 * $0 }.reduce(0, +))
            let magB = sqrt(b.map { $0 * $0 }.reduce(0, +))
            return (magA > 0 && magB > 0) ? dot / (magA * magB) : 0
        }

        /// Compute cosine similarity between the query vector and each document vector.
        let scored = zip(documents, docVectors)
            .map { document, vector in ScoredDocument(document: document, score: cosine(qVec, vector)) }
            .sorted { $0.score > $1.score }
            .map { ["document": $0.document, "score": $0.score] }

        /// Return the top K results.
        let topResults = Array(scored.prefix(topK))
        return MLResponse(outputs: ["results": topResults], info: nil)
    }
}
