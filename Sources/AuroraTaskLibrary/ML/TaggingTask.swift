//
//  TaggingTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/6/25.
//

import Foundation
import AuroraCore
import AuroraML

/**
 `TaggingTask` wraps any `MLServiceProtocol` (e.g. `TaggingService`) into a WorkflowComponent.

 - **Inputs**
    - `strings`: `[String]` of texts to tag.
 ### Outputs
 - `tags`: `[[Tag]]` — an array (per input) of `Tag` objects. Each `Tag` includes:
    - `token`: the substring that was tagged
    - `label`: the tag or category
    - `scheme`: the tagging scheme identifier
    - `confidence`: optional confidence score
    - `start`: starting index of the tagged token in the source string
    - `length`: length of the tagged token in the source string

    ### Use Cases
    - Tagging tokens in text for named entity recognition.
    - Annotating text for downstream NLP tasks.
    - Enriching text data with additional metadata.
    - Creating structured data from unstructured text.

    ### Example:
    **Input Strings:**
    - "The cat sat on the mat."
    - "The dog barked at the mailman."

    **Output JSON:**
    ```json
     {
       "tags": [
         [
           {"token":"cat","label":"animal","scheme":"nameType","confidence":0.98,"start":4,"length":3},
           {"token":"sat","label":"action","scheme":"nameType","confidence":0.75,"start":8,"length":3},
           {"token":"mat","label":"object","scheme":"nameType","confidence":0.82,"start":16,"length":3}
         ],
         [
           {"token":"dog","label":"animal","scheme":"nameType","confidence":0.96,"start":4,"length":3},
           {"token":"barked","label":"action","scheme":"nameType","confidence":0.88,"start":8,"length":3},
           {"token":"mailman","label":"person","scheme":"nameType","confidence":0.93,"start":18,"length":7}
         ]
       ]
     }
    ```

    ### Notes
    - Ensure that the `MLServiceProtocol` used supports tagging tasks.
    - The `strings` input is mandatory; an error will be thrown if it's empty.
    - The output `tags` will be an an array (per input) of `Tag` objects.
    - The order of tags corresponds to the order of tokens in the input strings.
    - The task is designed to be used within a workflow, and it will throw an error if the input strings are empty or if the `tags` output is missing from the ML response.
 */
public class TaggingTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /**
        Initializes a new `TaggingTask`.

        - Parameters:
            - name: The name of the task.
            - description: A description of the task.
            - service: The ML service to use for tagging.
            - strings: The list of strings to tag.
            - inputs: Additional inputs for the task. Defaults to an empty dictionary.
        - throws: An error if the input strings are empty or if the `tags` output is missing from the ML response.
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
            description: description ?? "Run token tagging using an MLServiceProtocol",
            inputs: inputs
        ) { inputs in
            let texts = inputs.resolve(key: "strings", fallback: strings) ?? []
            guard !texts.isEmpty else {
                throw NSError(domain: "TaggingTask", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "No strings provided"])
            }
            let response = try await service.run(request: MLRequest(inputs: ["strings": texts]))
            guard let tags = response.outputs["tags"] as? [[Tag]] else {
                throw NSError(domain: "TaggingTask", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "Missing 'tags' in ML response"])
            }
            return ["tags": tags]
        }
    }

    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
