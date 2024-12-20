//
//  LoadContextTask.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/**
 `LoadContextTask` is responsible for loading a `Context` object from disk.

 - **Inputs**
    - `filename`: The name of the file to load the context from (optional).
 - **Outputs**
    - `context`: The loaded context object.

 This task can be integrated into a workflow where context data needs to be retrieved from disk.
 */
public class LoadContextTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /**
     Initializes a `LoadContextTask` with the ability to load a context from disk.

     - Parameters:
        - name: Optionally pass the name of the task.
        - filename: Optionally pass the name of the file to load the context from.
        - inputs: Additional inputs for the task. Defaults to an empty dictionary.

     - Note: The `inputs` array can contain direct values for keys like `filename`, or dynamic references that will be resolved at runtime.
     */
    public init(
        name: String? = nil,
        filename: String? = nil,
        inputs: [String: Any?] = [:]
    ) {
        self.task = Workflow.Task(
            name: name,
            description: "Load the context from disk",
            inputs: inputs
        ) { inputs in
            /// Resolve the filename from the inputs if it exists, otherwise use the provided `filename` parameter or a default value
            let resolvedFilename = inputs.resolve(key: "filename", fallback: filename) ?? "default_context"

            do {
                let properFilename = resolvedFilename.hasSuffix(".json") ? resolvedFilename : "\(resolvedFilename).json"

                // Ensure the contexts directory exists
                let documentDirectory = try FileManager.default.createContextsDirectory()
                let fileURL = documentDirectory.appendingPathComponent(properFilename)

                // Load and decode the context from the file
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                let context = try decoder.decode(Context.self, from: data)

                return ["context": context]
            } catch {
                throw error
            }
        }
    }

    /// Converts this `LoadContextTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
