//
//  FetchContextsTask.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/**
 `FetchContextsTask` is responsible for retrieving a list of stored contexts from the disk.

 - **Inputs:**
    - `filenames`: An optional array of filenames (without extensions) specifying which contexts to retrieve.
 - **Outputs:**
    - `contexts`: An array of URLs pointing to the context files on disk.

 This task can be used in workflows requiring access to multiple stored contexts. If a list of specific filenames is provided, only those contexts will be fetched. Otherwise, all contexts will be retrieved.
 */
public class FetchContextsTask: WorkflowTask {

    /**
     Initializes a `FetchContextsTask` with an optional list of filenames.

     - Parameters:
        - name: The name of the task.
        - filenames: An optional array of filenames (without extensions) specifying which contexts to retrieve.

     - Returns: A `FetchContextsTask` instance.
     */
    public init(name: String? = nil, filenames: [String]? = nil) {
        super.init(
            name: name,
            description: "Fetch stored contexts from disk",
            inputs: ["filenames": filenames]
        )
    }

    /**
     Executes the task, fetching the specified contexts from the disk.

     - If specific filenames are provided in `inputs`, only those files will be retrieved.
     - If no filenames are provided, all context files with a `.json` extension in the directory will be fetched.

     - Throws: An error if the contexts directory cannot be accessed or any of the specified files cannot be retrieved.
     */
    public override func execute() async throws -> [String: Any] {
        do {
            // Ensure the contexts directory exists
            let documentDirectory = try FileManager.default.createContextsDirectory()

            // Retrieve the filenames from inputs if available, otherwise fetch all files
            let filenames = inputs["filenames"] as? [String]
            let contextFiles: [URL]
            if let filenames = filenames {
                // Fetch only the specified context files
                contextFiles = filenames.compactMap { filename in
                    // Only append .json if the filename doesn't already have it
                    let properFilename = filename.hasSuffix(".json") ? filename : "\(filename).json"
                    let fileURL = documentDirectory.appendingPathComponent(properFilename)
                    return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
                }
            } else {
                // Fetch all `.json` files in the directory if no specific filenames are provided
                let fileURLs = try FileManager.default.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil)
                contextFiles = fileURLs.filter { $0.pathExtension == "json" }
            }

            markCompleted()
            return  ["contexts": contextFiles]
        } catch {
            markFailed()
            throw error
        }
    }
}
