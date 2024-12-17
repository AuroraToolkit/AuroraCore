//
//  SaveContextTask.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/**
 `SaveContextTask` is responsible for saving a `Context` object to disk.

 - **Inputs**
    - `context`: The `Context` object to save.
    - `filename`: The name of the file (without extension) used for saving the context.
 - **Outputs**
    - `filename`: The name of the file where the context was saved.

 This task can be integrated in a workflow where context data needs to be saved to disk.

 - Note: The task ensures that a dedicated `contexts/` directory exists in the documents folder.
 */
public class SaveContextTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /**
     Initializes a `SaveContextTask` with the context and filename.

     - Parameters:
        - name: Optionally pass the name of the task.
        - context: The `Context` object to save.
        - filename: The name of the file (without extension) used for saving the context.
     */
    public init(name: String? = nil, context: Context, filename: String) {
        var inputs: [String: Any?] = [:]
        inputs["context"] = context
        inputs["filename"] = filename.hasSuffix(".json") ? filename : "\(filename).json"
        self.task = Workflow.Task(
            name: name,
            description: "Save the context to disk",
            inputs: inputs
        ) { inputs in
            guard let context = inputs["context"] as? Context,
                  let filename = inputs["filename"] as? String else {
                throw NSError(domain: "SaveContextTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid inputs for SaveContextTask"])
            }
            do {
                // Ensure the contexts directory exists
                let documentDirectory = try FileManager.default.createContextsDirectory()

                // Avoid appending .json if it already exists
                let properFilename = filename.hasSuffix(".json") ? filename : "\(filename).json"
                let fileURL = documentDirectory.appendingPathComponent(properFilename)

                // Encode the context to JSON and save to file
                let encoder = JSONEncoder()
                let data = try encoder.encode(context)
                try data.write(to: fileURL)

                return ["filename": properFilename]
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
