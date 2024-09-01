//
//  TrimmingTask.swift
//
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

public class TrimmingTask: WorkflowTask {

    public var output: String?

    /**
     The preferred initializer for creating a `TrimmingTask`.

     - Parameters:
        - name: The name of the task.
        - description: A detailed description of the task.
        - input: The string to be trimmed.
        - tokenLimit: The maximum allowed token count (default is 1,024).
        - buffer: A buffer percentage to apply when calculating the token limit (default is 5%).
        - strategy: The trimming strategy to apply (default is `.middle`).
     */
    public init(name: String, description: String, input: String? = nil, tokenLimit: Int? = nil, buffer: Double? = nil, strategy: String.TrimmingStrategy? = nil) {
        var inputs: [String: Any?] = [:]
        inputs["input"] = input
        inputs["tokenLimit"] = tokenLimit
        inputs["buffer"] = buffer
        inputs["strategy"] = strategy
        super.init(name: name, description: description, inputs: inputs)
    }

    /**
     A convenience initializer for creating a `TrimmingTask` using a dictionary of inputs.

     This initializer is not preferred. Use the designated initializer `init(name:description:input:tokenLimit:buffer:strategy:)` instead.

     - Parameters:
        - name: The name of the task.
        - description: A detailed description of the task.
        - inputs: A dictionary containing the necessary inputs for the task.
     */
    public convenience init(name: String, description: String, inputs: [String: Any?]) {
        let input = inputs["input"] as? String
        let tokenLimit = inputs["tokenLimit"] as? Int
        let buffer = inputs["buffer"] as? Double
        let strategy = inputs["strategy"] as? String.TrimmingStrategy
        self.init(name: name, description: description, input: input, tokenLimit: tokenLimit, buffer: buffer, strategy: strategy)
    }

    public override func execute() async throws {
        // Set default values if they are missing
        let input = inputs["input"] as? String ?? ""
        let tokenLimit = inputs["tokenLimit"] as? Int ?? 1024
        let buffer = inputs["buffer"] as? Double ?? 0.05
        let strategy = inputs["strategy"] as? String.TrimmingStrategy ?? .middle

        // Validate required inputs
        guard !input.isEmpty else {
            markFailed()
            throw NSError(domain: "TrimmingTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid inputs"])
        }

        // Perform the trimming operation
        output = input.trimmedToFit(tokenLimit: tokenLimit, buffer: buffer, strategy: strategy)
        markCompleted(withOutputs: ["trimmedString": output as Any])
    }
}
