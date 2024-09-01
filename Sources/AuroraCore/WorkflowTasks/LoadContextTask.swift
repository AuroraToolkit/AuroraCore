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

    /// The file URL where the context will be loaded from.
    private let fileURL: URL

    /**
     Initializes a `LoadContextTask` with a filename.

     - Parameter filename: The name of the file (without extension) used for loading the context.
     - Returns: A `LoadContextTask` instance.
     */
    public init(filename: String) {
        // Attempt to retrieve the document directory safely
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Document directory not found")
        }
        self.fileURL = documentDirectory.appendingPathComponent("\(filename).json")
        super.init(name: "Load Context", description: "Load the context from disk")
    }

    public override func execute() async throws {
        do {
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
