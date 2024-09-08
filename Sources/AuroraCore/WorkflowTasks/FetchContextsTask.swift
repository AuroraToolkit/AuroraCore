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

    /**
     Initializes a `FetchContextsTask` to retrieve all stored contexts.

     - Returns: A `FetchContextsTask` instance.
     */
    public init() {
        super.init(name: "Fetch Contexts", description: "Fetch all stored contexts from disk")
    }

    public override func execute() async throws {
        do {
            // Ensure the contexts directory exists
            let documentDirectory = try FileManager.default.createContextsDirectory()

            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil)

            // Filter for JSON files (assuming all contexts are stored as .json)
            let contextFiles = fileURLs.filter { $0.pathExtension == "json" }

            markCompleted(withOutputs: ["contexts": contextFiles])
        } catch {
            markFailed()
            throw error
        }
    }
}
