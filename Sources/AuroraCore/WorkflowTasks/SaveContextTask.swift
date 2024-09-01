//
//  SaveContextTask.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/**
 `SaveContextTask` is responsible for saving a `Context` object to disk using JSON encoding.

 This task can be integrated into a workflow where context data needs to be persisted.
 */
public class SaveContextTask: WorkflowTask {

    /// The `Context` object to be saved.
    private let context: Context

    /// The file URL where the context will be saved.
    private let fileURL: URL

    /**
     Initializes a `SaveContextTask` with a context and filename.

     - Parameters:
        - context: The `Context` object to be saved.
        - filename: The name of the file (without extension) used for saving the context.
     - Returns: A `SaveContextTask` instance.
     */
    public init(context: Context, filename: String) {
        self.context = context
        // Attempt to retrieve the document directory safely
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Document directory not found")
        }
        self.fileURL = documentDirectory.appendingPathComponent("\(filename).json")
        super.init(name: "Save Context", description: "Save the context to disk")
    }

    public override func execute() async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(context)
            try data.write(to: fileURL)
            markCompleted(withOutputs: ["fileURL": fileURL])
        } catch {
            markFailed()
            throw error
        }
    }
}
