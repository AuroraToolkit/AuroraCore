//
//  TrimmingTask.swift
//
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

public class TrimmingTask: WorkflowTask {

    /**
     Initializes a `TrimmingTask` to trim multiple strings.

     - Parameter strings: An array of strings to be trimmed. Can contain one or multiple items.
     - Parameter tokenLimit: The maximum allowed token count (default is 1,024).
     - Parameter buffer: A buffer percentage to apply when calculating the token limit (default is 5%).
     - Parameter strategy: The trimming strategy to apply (default is `.middle`).
     */
    public init(strings: [String], tokenLimit: Int? = 1024, buffer: Double? = 0.05, strategy: String.TrimmingStrategy? = .middle) {
        let name = strings.count <= 1 ? "Trimming Task" : "Trim Multiple Strings"
        let description = strings.count <= 1 ? "Trim string to fit within the token limit using \(strategy!) strategy" : "Trim multiple strings to fit within the token limit using \(strategy!) strategy"
        super.init(
            name: name,
            description: description,
            inputs: [
                "strings": strings,
                "tokenLimit": tokenLimit,
                "buffer": buffer,
                "strategy": strategy
            ]
        )
    }

    /**
     Convenience initializer for creating a `TrimmingTask` to trim a single string.

     - Parameter string: The single string to be trimmed.
     - Parameter tokenLimit: The maximum allowed token count (default is 1,024).
     - Parameter buffer: A buffer percentage to apply when calculating the token limit (default is 5%).
     - Parameter strategy: The trimming strategy to apply (default is `.middle`).
     */
    public convenience init(string: String, tokenLimit: Int? = 1024, buffer: Double? = 0.05, strategy: String.TrimmingStrategy? = .middle) {
        self.init(strings: [string], tokenLimit: tokenLimit, buffer: buffer, strategy: strategy)
    }

    public override func execute() async throws {
        // Retrieve inputs with default values
        let strings = inputs["strings"] as? [String] ?? []
        let tokenLimit = inputs["tokenLimit"] as? Int ?? 1024
        let buffer = inputs["buffer"] as? Double ?? 0.05
        let strategy = inputs["strategy"] as? String.TrimmingStrategy ?? .middle

        // Validate required inputs
        guard !strings.isEmpty else {
            markFailed()
            throw NSError(domain: "TrimmingTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid inputs for TrimmingTask"])
        }

        // Perform the trimming operation for each string in the array
        let trimmedStrings = strings.map { $0.trimmedToFit(tokenLimit: tokenLimit, buffer: buffer, strategy: strategy) }

        // Store the results in outputs
        markCompleted(withOutputs: ["trimmedStrings": trimmedStrings])
    }
}
