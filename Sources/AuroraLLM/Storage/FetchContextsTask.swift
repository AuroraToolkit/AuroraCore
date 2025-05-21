//
//  FetchContextsTask.swift
//  AuroraCore
//

import AuroraCore
import Foundation

/**
 `FetchContextsTask` is responsible for retrieving a list of stored contexts from the disk.

 - **Inputs:**
    - `filenames`: An optional array of filenames (without extensions) specifying which contexts to retrieve.
 - **Outputs:**
    - `contexts`: An array of URLs pointing to the context files on disk.

 This task can be used in workflows requiring access to multiple stored contexts. If a list of specific filenames is provided, only those contexts will be fetched.
 Otherwise, all contexts will be retrieved.
 */
public struct FetchContextsTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /**
     Initializes a `FetchContextsTask` with an optional name and list of filenames.

     - Parameters:
        - name: An optional name for the task. Defaults to the type name if `nil`.
        - filenames: An optional array of filenames (without extensions) specifying which contexts to retrieve.
        - inputs: Additional inputs for the task. Defaults to an empty dictionary.

     - Note: The `inputs` array can contain direct values for keys like `filenames`, or dynamic references that will be resolved at runtime.
     */
    public init(
        name: String? = nil,
        filenames: [String]? = nil,
        inputs: [String: Any?] = [:]
    ) {
        task = Workflow.Task(
            name: name,
            description: "Fetch stored contexts from disk",
            inputs: inputs
        ) { inputs in
            /// Resolve filenames from inputs or use the provided `filenames` parameter
            let resolvedFilenames = inputs.resolve(key: "filenames", fallback: filenames)

            do {
                // Ensure the contexts directory exists
                let documentDirectory = try FileManager.default.createContextsDirectory()
                let existingFilenames = try FileManager.default.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil)
                    .map { $0.lastPathComponent.lowercased() }

                let contextFiles: [URL]
                if let filenames = resolvedFilenames {
                    contextFiles = filenames.compactMap { filename in
                        let normalizedFilename = filename.hasSuffix(".json") ? filename.lowercased() : "\(filename).json".lowercased()
                        if let matchingFile = existingFilenames.first(where: { $0 == normalizedFilename }) {
                            return documentDirectory.appendingPathComponent(matchingFile)
                        }
                        return nil
                    }
                } else {
                    let fileURLs = try FileManager.default.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil)
                    contextFiles = fileURLs.filter { $0.pathExtension.lowercased() == "json" }
                }

                return ["contexts": contextFiles]
            } catch {
                throw error
            }
        }
    }

    /// Converts this `FetchContextsTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
