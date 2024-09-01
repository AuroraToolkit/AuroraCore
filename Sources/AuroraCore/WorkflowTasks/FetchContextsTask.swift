//
//  FetchContextsTask.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/**
 `FetchContextsTask` is responsible for retrieving a list of all stored contexts from the disk.

 This task can be integrated into a workflow where a list of all available contexts needs to be fetched.
 */
public class FetchContextsTask: WorkflowTask {

    /// The directory where the context files are stored.
    private let directoryURL: URL

    /**
     Initializes a `FetchContextsTask` to retrieve all stored contexts.

     - Parameter directory: The directory where context files are stored. Defaults to the app's document directory.
     - Returns: A `FetchContextsTask` instance.
     */
    public init(directory: URL? = nil) {
        if let directory = directory {
            self.directoryURL = directory
        } else {
            // Attempt to retrieve the document directory safely
            guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                fatalError("Document directory not found")
            }
            self.directoryURL = documentDirectory
        }
        super.init(name: "Fetch Contexts", description: "Fetch all stored contexts from disk")
    }

    public override func execute() async throws {
        do {
            let fileManager = FileManager.default
            let fileURLs = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)

            // Filter for JSON files (assuming all contexts are stored as .json)
            let contextFiles = fileURLs.filter { $0.pathExtension == "json" }

            markCompleted(withOutputs: ["contexts": contextFiles])
        } catch {
            markFailed()
            throw error
        }
    }
}
