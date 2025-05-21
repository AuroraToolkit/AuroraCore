//
//  EmbeddingService.swift
//  AuroraML
//
//  Created by Dan Murrell Jr on 05/15/25.
//

import AuroraCore
import Foundation
import NaturalLanguage

/**
  A service that converts text into fixed-length vector embeddings using Apple’s `NLEmbedding`.

  - **Inputs**
     - `strings`: `[String]` of texts to embed.
  - **Outputs**
     - `embeddings`: `[[Double]]` — an array (one per input string) of floating-point vectors.

  ### Example
  ```swift
  // load the built-in sentence embedding for English
  guard let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english) else {
     fatalError("Embedding model unavailable")
  }
  let enbeddingService = EmbeddingService(
     name: "EnglishSentenceEmbedding",
     embedding: sentenceEmbedding
  )
  let texts = ["Hello world", "How are you?"]
  let resp = try await enbeddingService.run(
     request: MLRequest(inputs: ["strings": texts])
  )
  let vectors = resp.outputs["embeddings"] as! [[Double]]
  // vectors[0].count == sentenceEmbedding.dimension
 ```
  */
public final class EmbeddingService: MLServiceProtocol {
    public var name: String
    public let embedding: NLEmbedding
    private let logger: CustomLogger?

    /**
     - Parameters:
        - name: Identifier for this service.
        - embedding: An `NLEmbedding` instance (e.g. `.wordEmbedding(for:)` or `.sentenceEmbedding(for:)`).
        - logger: Optional logger for debugging.
     */
    public init(name: String, embedding: NLEmbedding, logger: CustomLogger? = nil) {
        self.name = name
        self.embedding = embedding
        self.logger = logger
    }

    public func run(request: MLRequest) async throws -> MLResponse {
        guard let texts = request.inputs["strings"] as? [String] else {
            logger?.error("Missing 'strings' input", category: name)
            throw NSError(
                domain: name,
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Input 'strings' missing"]
            )
        }

        var allVectors = [[Double]]()
        for text in texts {
            guard let vec = embedding.vector(for: text) else {
                logger?.error("Failed to embed text: \(text)", category: name)
                throw NSError(
                    domain: name,
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Embedding failed for text: \(text)"]
                )
            }
            allVectors.append(vec)
        }

        return MLResponse(outputs: ["embeddings": allVectors], info: nil)
    }
}
