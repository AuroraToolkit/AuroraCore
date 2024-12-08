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
public class LoadContextTask: WorkflowTask {

    /**
     Initializes a `LoadContextTask` with the ability to load a context from disk.

     - Parameters:
        - name: Optionally pass the name of the task.
        - filename: Optionally pass the name of the file to load the context from.
     */
    public init(name: String? = nil, filename: String? = nil) {
        super.init(
            name: name,
            description: "Load the context from disk",
            inputs: ["filename": filename]
        )
    }

    /**
     Executes the task by loading the context from the specified file or a default file.

     - Throws: An error if the context could not be loaded (e.g., file not found, decoding error).
     */
    public override func execute() async throws -> [String: Any] {
        do {
            // Retrieve the filename from inputs or use a default
            let filename = inputs["filename"] as? String ?? "default_context"
            let properFilename = filename.hasSuffix(".json") ? filename : "\(filename).json"

            // Ensure the contexts directory exists
            let documentDirectory = try FileManager.default.createContextsDirectory()
            let fileURL = documentDirectory.appendingPathComponent(properFilename)

            // Load and decode the context from the file
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let context = try decoder.decode(Context.self, from: data)

            markCompleted()
            return ["context": context]
        } catch {
            markFailed()
            throw error
        }
    }
}
