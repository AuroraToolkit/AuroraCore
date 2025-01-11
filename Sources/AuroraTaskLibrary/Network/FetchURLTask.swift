//
//  FetchURLTask.swift
//  AuroraCore
//

import Foundation
import AuroraCore

/**
 `FetchURLTask` fetches the contents of a specified URL and returns the raw data.

 - **Inputs**
    - `url`: The string for the `URL` to fetch.
    - `headers`: An optional dictionary of headers to include in the request.
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
        - headers: An optional dictionary of headers to include in the request.
        - session: The `URLSession` to use for the request. Defaults to `.shared`.
        - inputs: Additional inputs for the task. Defaults to an empty dictionary.

     - Throws: An error if the `url` parameter is invalid.
     - Note: The `inputs` array can contain direct values for keys like `url` and `headers`, or dynamic references that will be resolved at runtime.
     */
    public init(
        name: String? = nil,
        url: String? = nil,
        headers: [String: String]? = nil,
        session: URLSession = .shared,
        inputs: [String: Any?] = [:]
    ) {
        self.session = session
        self.task = Workflow.Task(
            name: name ?? String(describing: Self.self),
            description: "Fetches data from \(url ?? "a URL")",
            inputs: inputs
        ) { inputs in
            /// Resolve the `url` from the inputs if it exists, otherwise use the provided `url` parameter
            let resolvedUrl = inputs.resolve(key: "url", fallback: url)

            guard let urlString = resolvedUrl else {
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

            /// Resolve headers from inputs if provided
            let resolvedHeaders = inputs.resolve(key: "headers", fallback: headers) ?? [:]

            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            // Add headers if available
            for (headerField, value) in resolvedHeaders {
                request.addValue(value, forHTTPHeaderField: headerField)
            }

            let (data, _) = try await session.data(for: request)
            return ["data": data]
        }
    }

    /// Converts this `FetchURLTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
