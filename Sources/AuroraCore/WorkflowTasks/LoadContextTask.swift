//
//  LoadContextTask.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/**
 `LoadContextTask` is responsible for loading a `Context` object from disk.

 This task can be integrated into a workflow where context data needs to be retrieved from disk.
 */
public class LoadContextTask: WorkflowTask {

    /// The filename where the context will be loaded from.
    private let filename: String

    /**
     Initializes a `LoadContextTask` with a filename.

     - Parameter filename: The name of the file (without extension) used for loading the context.
     - Returns: A `LoadContextTask` instance.
     */
    public init(filename: String) {
        // Ensure that the filename ends with .json only once
        self.filename = filename.hasSuffix(".json") ? filename : "\(filename).json"

        super.init(name: "Load Context", description: "Load the context from disk")
    }

    public override func execute() async throws {
        do {
            // Ensure the contexts directory exists
            let documentDirectory = try FileManager.default.createContextsDirectory()

            let fileURL = documentDirectory
                .appendingPathComponent(filename)

            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let context = try decoder.decode(Context.self, from: data)
            markCompleted(withOutputs: ["context": context])
        } catch {
            markFailed()
            throw error
        }
    }
}
