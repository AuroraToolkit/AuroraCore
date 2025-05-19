//
//  ClassificationMLTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/18/25.
//

import Foundation
import AuroraCore
import AuroraML

/**
 `ClassificationMLTask` wraps any `MLServiceProtocol` (e.g. `ClassificationService`)
 into a `WorkflowComponent`.

 - **Inputs**
    - `strings`: `[String]` — an array of texts to classify.
 - **Outputs**
    - `tags`: `[Tag]` — a flat array of `Tag` objects, one per predicted label. Each `Tag` includes:
        - `token`: the substring that was tagged
        - `label`: the tag or category
        - `scheme`: the tagging scheme identifier
        - `confidence`: optional confidence score
        - `start`: starting index of the tagged token in the source string
        - `length`: length of the tagged token in the source string

 ### Example
 ```swift
 let model = try NLModel(contentsOf: myModelURL)
 let service = ClassificationService(
    name: "SentimentClassifier",
    model: model,
    scheme: "sentiment",
    maxResults: 2
 )
 let task = ClassificationMLTask(
    service: service,
    strings: ["I love Swift!", "This is so-so."]
 )
 guard case let .task(wrapped) = task.toComponent() else { return }
 let outputs = try await wrapped.execute()
 let tags = outputs["tags"] as? [Tag]
 print(tags)
```
 */
public class ClassificationMLTask: WorkflowComponent {
    private let task: Workflow.Task

    /**
     - Parameters:
        - name: Optional override for workflow task name.
        - description: Optional override for the workflow description.
        - service: An `MLServiceProtocol` that emits `["tags": [Tag]]`.
        - strings: Fallback array of strings to classify.
        - inputs: Additional inputs to the task.
     */
    public init(
        name: String? = nil,
        description: String? = nil,
        service: MLServiceProtocol,
        strings: [String]? = nil,
        inputs: [String: Any?] = [:]
    ) {
        self.task = Workflow.Task(
            name: name ?? String(describing: Self.self),
            description: description ?? "Run text classification using an MLServiceProtocol",
            inputs: inputs
        ) { inputs in
            let texts = inputs.resolve(key: "strings", fallback: strings) ?? []
            guard !texts.isEmpty else {
                throw NSError(
                    domain: "ClassificationMLTask",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No strings provided"]
                )
            }
            let response = try await service.run(
                request: MLRequest(inputs: ["strings": texts])
            )
            guard let tags = response.outputs["tags"] as? [Tag] else {
                throw NSError(
                    domain: "ClassificationMLTask",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Missing 'tags' in ML response"]
                )
            }
            return ["tags": tags]
        }
    }

    public func toComponent() -> Workflow.Component {
        .task(task)
    }

}
