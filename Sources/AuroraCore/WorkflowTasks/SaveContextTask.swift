//
//  SaveContextTask.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/**
 `SaveContextTask` is responsible for saving a `Context` object to disk.

 The task ensures that a dedicated `contexts/` directory exists in the documents folder.
 */
public class SaveContextTask: WorkflowTask {

    /// The context to be saved.
    private let context: Context

    /// The filename used to store the context.
    private let filename: String

    /**
     Initializes a `SaveContextTask` with the context and filename.

     - Parameters:
        - context: The `Context` object to save.
        - filename: The name of the file (without extension) used for saving the context.
     */
    public init(context: Context, filename: String) {
        self.context = context
        self.filename = filename
        super.init(name: "Save Context", description: "Save the context to disk")
    }

    public override func execute() async throws {
        do {
            // Ensure the contexts directory exists
            let documentDirectory = try FileManager.default.createContextsDirectory()

            // Prepare the file URL
            let fileURL = documentDirectory.appendingPathComponent("\(filename).json")

            // Encode the context to JSON and save to file
            let encoder = JSONEncoder()
            let data = try encoder.encode(context)
            try data.write(to: fileURL)

            markCompleted()
        } catch {
            markFailed()
            throw error
        }
    }
}
