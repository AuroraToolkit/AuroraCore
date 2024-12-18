//
//  FetchURLTask.swift
//  AuroraCore
//

import Foundation

/**
 `FetchURLTask` fetches the contents of a specified URL and returns the raw data.

 - **Inputs**
    - `url`: The string for the `URL` to fetch.
 - **Outputs**
    - `data`: The raw data fetched from the URL.

 This task wraps `Workflow.Task` and can be used in workflows where external data needs to be retrieved, such as downloading files,
 fetching JSON, or reading RSS feeds.
 */
public struct FetchURLTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /// The URLSession used to fetch the URL.
    private let session: URLSession

    /**
     Initializes a `FetchURLTask`.

     - Parameters:
        - name: The name of the task (default is `FetchURLTask`).
        - url: The string for the `URL` to fetch.
        - session: The `URLSession` to use for the request. Defaults to `.shared`.
        - inputs: Additional inputs for the task. If a value for the `url` key is provided, it will overwritten by the `url` parameter.

     - Throws: An error if the `url` parameter is invalid.
     - Note: The `url` parameter provided during initialization takes precedence over inputs with the same key.
     However, at execution time, any resolved `url` value in the `inputs` dictionary will overwrite both the initialized parameter and the raw input value.
     This ensures dynamic flexibility within the workflow.
     */
    public init(
        name: String? = nil,
        url: String? = nil,
        session: URLSession = .shared,
        inputs: [String: Any?] = [:]
    ) {
        // Merge direct parameters into inputs
        var mergedInputs = inputs
        if let url {
            mergedInputs["url"] = url
        }

        self.session = session
        self.task = Workflow.Task(
            name: name,
            description: "Fetches data from \(url ?? "a URL")",
            inputs: mergedInputs
        ) { inputs in
            guard let urlString = inputs["url"] as? String else {
                throw NSError(
                    domain: "FetchURLTask",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "URL input is missing or not a valid string."]
                )
            }
            guard let url = URL(string: urlString) else {
                throw NSError(
                    domain: "FetchURLTask",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "URL string provided is invalid: \(urlString)"]
                )
            }
            let (data, _) = try await session.data(from: url)
            return ["data": data]
        }
    }

    /// Converts this `FetchURLTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
