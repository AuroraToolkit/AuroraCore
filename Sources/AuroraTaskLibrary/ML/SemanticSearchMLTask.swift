//
//  SemanticSearchMLTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/17/25.
//

import Foundation
import AuroraCore
import AuroraML

/**
 `SemanticSearchMLTask` wraps any `MLServiceProtocol` that performs
 semantic search (emitting `[[String: Any]]` under the `"results"` key)
 into a `WorkflowComponent`.

 - **Inputs**
    - `query`: `String` to search for.
    - `vector`: `[Double]` raw embedding to search with.
 - **Outputs**
    - `results`: `[[String: Any]]` — an array of
        - `"document"`: `String`
        - `"score"`: `Double`

 ### Example
 ```swift
 let docs = ["The cat sat", "A quick brown fox"]
 let embeddingService = EmbeddingService(
    name: "SentenceEmbedding",
    embedding: NLEmbedding.sentenceEmbedding(for: .english)!
 )
 let searchService = try SemanticSearchService(
    name: "DemoSearch",
    embeddingService: embeddingService,
    documents: docs,
    topK: 1
 )
 let task = SemanticSearchMLTask(
    service: searchService,
    query: "fast fox"
 )
 guard case let .task(wrapped) = task.toComponent() else { return }
 let outputs = try await wrapped.execute()
 let hits = outputs["results"] as? [[String: Any]]
 print(hits)
```
 */
public class SemanticSearchMLTask: WorkflowComponent {
    private let task: Workflow.Task

    /**
     - Parameters:
        - name: Optional override for the workflow task name.
        - description: Optional override for the workflow description.
        - service: A `SemanticSearchService` or any `MLServiceProtocol` emitting `"results"`.
        - query: Fallback `String` query to use if not provided at execution time.
        - vector: Fallback raw embedding if not providing a query.
        - inputs: Additional inputs to the task.
     */
    public init(
        name: String? = nil,
        description: String? = nil,
        service: MLServiceProtocol,
        query: String? = nil,
        vector: [Double]? = nil,
        inputs: [String: Any?] = [:]
    ) {
        self.task = Workflow.Task(
            name: name ?? String(describing: Self.self),
            description: description ?? "Run semantic search over documents",
            inputs: inputs
        ) { inputs in
            // Resolve query or vector fallback
            let useQuery: String? = inputs.resolve(key: "query", fallback: query)
            let useVector: [Double]? = inputs.resolve(key: "vector", fallback: vector)
            guard useQuery != nil || useVector != nil else {
                throw NSError(
                    domain: "SemanticSearchMLTask",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Missing 'query' or 'vector' input"]
                )
            }

            let resp: MLResponse
            if let q = useQuery {
                resp = try await service.run(request: MLRequest(inputs: ["query": q]))
            } else {
                resp = try await service.run(request: MLRequest(inputs: ["vector": useVector!]))
            }

            guard let results = resp.outputs["results"] as? [[String: Any]] else {
                throw NSError(
                    domain: "SemanticSearchMLTask",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Missing 'results' in ML response"]
                )
            }
            return ["results": results]
        }
    }

    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
