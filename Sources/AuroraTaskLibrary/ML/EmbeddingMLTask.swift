//
//  EmbeddingMLTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/17/25.
//

import Foundation
import AuroraCore
import AuroraML

/**
 `EmbeddingMLTask` wraps  wraps any `MLServiceProtocol` that produces embeddings into a `WorkflowComponent`.

 - **Inputs**
    - `strings`: `[String]` of texts to embed.
 - **Outputs**
    - `embeddings`: `[[Double]]` — an array (one per input string) of floating-point vectors.

 ### Example
 ```swift
 // load the built-in sentence embedding for English
 guard let sentenceEmbedder = NLEmbedding.sentenceEmbedding(for: .english) else {
    fatalError("Embedding model unavailable")
 }
 let embedSvc = EmbeddingService(
    name: "EnglishSentenceEmbedding",
    embedding: sentenceEmbedder
 )
 let task = EmbeddingMLTask(
    name: "EmbedSentences",
    embeddingService: embedSvc,
    strings: ["Hello world", "How are you?"]
 )
 guard case let .task(wrapped) = task.toComponent() else { return }
 let outputs = try await wrapped.execute()
 let vectors = outputs["embeddings"] as! [[Double]]
 // vectors[0].count == sentenceEmbedder.dimension
 */
public class EmbeddingMLTask: WorkflowComponent {
    private let task: Workflow.Task

    /**
     - Parameters:
        - name: Optional override for the workflow task name.
        - description: Optional override for the task description.
        - embeddingService: Any `MLServiceProtocol` that returns `[[Double]]` under `"embeddings"`.
        - strings: The texts to embed.
        - inputs: Additional inputs (fallbacks).
     */
    public init(
        name: String? = nil,
        description: String? = nil,
        embeddingService: MLServiceProtocol,
        strings: [String]? = nil,
        inputs: [String: Any?] = [:]
    ) {
        self.task = Workflow.Task(
            name: name ?? String(describing: Self.self),
            description: description ?? "Embed text strings into vector representations",
            inputs: inputs
        ) { inputs in
            let texts = inputs.resolve(key: "strings", fallback: strings) ?? []
            guard !texts.isEmpty else {
                throw NSError(
                    domain: "EmbeddingMLTask",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No strings provided"]
                )
            }
            let resp = try await embeddingService.run(
                request: MLRequest(inputs: ["strings": texts])
            )
            guard let emb = resp.outputs["embeddings"] as? [[Double]] else {
                throw NSError(
                    domain: "EmbeddingMLTask",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Missing 'embeddings' in ML response"]
                )
            }
            return ["embeddings": emb]
        }
    }

    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
