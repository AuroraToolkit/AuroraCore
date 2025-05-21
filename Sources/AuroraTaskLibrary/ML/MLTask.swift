//
//  MLTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/5/25.
//

import AuroraCore
import AuroraML
import Foundation

public class MLTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /**
        Initializes a new `MLTask`.

        - Parameters:
            - name: The name of the task.
            - mlService: The ML service to use for the task.
            - request: The `MLRequest` object containing the input data.
            - inputs: Additional inputs for the task. Defaults to an empty dictionary.

     - Note: The `inputs` array can contain direct values for keys like `request`, or dynamic references that will be resolved at runtime.
     */
    public init(
        name: String? = nil,
        description: String? = nil,
        mlService: MLServiceProtocol,
        request: MLRequest? = nil,
        inputs: [String: Any?] = [:]
    ) {
        task = Workflow.Task(
            name: name ?? String(describing: Self.self),
            description: description ?? "Run on an on-device ML model",
            inputs: inputs
        ) { inputs in
            // Resolve MLRequest from inputs or fallback to provided request
            let resolved = inputs["request"] as? MLRequest ?? request
            guard let mlRequest = resolved else {
                throw NSError(
                    domain: "MLTask",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "MLRequest is missing."]
                )
            }

            // Execute model
            let response = try await mlService.run(request: mlRequest)

            // Return the raw outputs under key "result"
            return ["result": response.outputs]
        }
    }

    /// Converts this `MLTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
