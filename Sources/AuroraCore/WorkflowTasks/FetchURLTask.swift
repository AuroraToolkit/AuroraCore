//
//  FetchURLTask.swift
//  AuroraCore
//

import Foundation

/**
 `FetchURLTask` fetches the contents of a specified URL and returns the raw data.

 - **Inputs**
    - `url`: The URL to fetch.
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
        - name: The name of the task.
        - url: The URL to fetch.
        - session: The URLSession to use for the request. Defaults to `.shared`.
     */
    public init(name: String? = nil, url: URL, session: URLSession = .shared) {
        self.session = session
        self.task = Workflow.Task(
            name: name,
            description: "Fetches data from \(url.absoluteString)",
            inputs: ["url": url]
        ) { inputs in
            guard let url = inputs["url"] as? URL else {
                throw NSError(domain: "FetchURLTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL input"])
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
