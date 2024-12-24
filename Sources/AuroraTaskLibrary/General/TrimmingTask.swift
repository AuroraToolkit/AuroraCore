//
//  TrimmingTask.swift
//
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation
import AuroraCore

/**
 `TrimmingTask` is responsible for trimming strings to fit within a specified token limit.

 - **Inputs**
 - `strings`: An array of strings to be trimmed. Can contain one or multiple items.
 - `tokenLimit`: The maximum allowed token count (default is 1,024).
 - `buffer`: A buffer percentage to apply when calculating the token limit (default is 5%).
 - `strategy`: The trimming strategy to apply (default is `.middle`).
 - **Outputs**
 - `trimmedStrings`: An array of trimmed strings.

 This task can be integrated in a workflow where string trimming is required to fit within a token limit.
 */
public class TrimmingTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /**
     - Parameters:
        - name: The name of the task.
        - strings: An array of strings to be trimmed. Can contain one or multiple items.
        - tokenLimit: The maximum allowed token count (default is 1,024).
        - buffer: A buffer percentage to apply when calculating the token limit (default is 5%).
        - strategy: The trimming strategy to apply (default is `.middle`).
        - inputs: Additional inputs for the task. If a value for a key is provided, it will overwritten by the parameter.
     */
    public init(
        name: String? = nil,
        strings: [String]? = nil,
        tokenLimit: Int = 1024,
        buffer: Double = 0.05,
        strategy: String.TrimmingStrategy = .middle,
        inputs: [String: Any?] = [:]
    ) {
        let stringsCount = strings?.count ?? 0
        let description = stringsCount <= 1 ? "Trim string to fit within the token limit using \(strategy) strategy" : "Trim multiple strings to fit within the token limit using \(strategy) strategy"
        self.task = Workflow.Task(
            name: name,
            description: description,
            inputs: inputs
        ) { inputs in
            /// Resolve values from the inputs if it exists, otherwise use the provided parameter or an empty array
            let resolvedStrings = inputs.resolve(key: "strings", fallback: strings) ?? []

            // Validate required inputs
            guard !resolvedStrings.isEmpty else {
                throw NSError(domain: "TrimmingTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid inputs for TrimmingTask"])
            }

            // Perform the trimming operation for each string in the array
            let trimmedStrings = resolvedStrings.map {
                $0.trimmedToFit(tokenLimit: tokenLimit, buffer: buffer, strategy: strategy)
            }

            return ["trimmedStrings": trimmedStrings]
        }
    }

    /**
     Convenience initializer for creating a `TrimmingTask` to trim a single string.

     - Parameter string: The single string to be trimmed.
     - Parameter tokenLimit: The maximum allowed token count (default is 1,024).
     - Parameter buffer: A buffer percentage to apply when calculating the token limit (default is 5%).
     - Parameter strategy: The trimming strategy to apply (default is `.middle`).
     */
    public convenience init(string: String, tokenLimit: Int = 1024, buffer: Double = 0.05, strategy: String.TrimmingStrategy = .middle) {
        self.init(strings: [string], tokenLimit: tokenLimit, buffer: buffer, strategy: strategy)
    }

    /// Converts this `LoadContextTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
