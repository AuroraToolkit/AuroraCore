//
//  FetchURLTask.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/3/24.
//

import Foundation

/**
 `FetchURLTask` fetches the contents of a specified URL and returns the raw data.

 - **Inputs**
    - `url`: The URL to fetch.
 - **Outputs**
    - `data`: The raw data fetched from the URL.

 This task can be used in workflows where external data needs to be retrieved, such as downloading files, fetching JSON, or reading RSS feeds.
 */
public class FetchURLTask: WorkflowTask {

    /// The URL to fetch.
    private let url: URL

    /// The URLSession used to fetch the URL.
    private let session: URLSession

    /**
     Initializes a `FetchURLTask` with the URL to fetch.

     - Parameters:
        - name: The name of the task.
        - url: The URL to fetch.
        - session: The URLSession used to fetch the URL. Defaults to `.shared`.
     */
    public init(name: String? = nil, url: URL, session: URLSession = .shared) {
        self.url = url
        self.session = session
        super.init(
            name: name,
            description: "Fetches data from the specified URL",
            inputs: ["url": url]
        )
    }

    /**
     Executes the task by fetching the contents of the specified URL.

     - Throws: An error if the URL cannot be fetched or the data is invalid.
     */
    public override func execute() async throws -> [String: Any] {
        guard let url = inputs["url"] as? URL else {
            markFailed()
            throw NSError(domain: "FetchURLTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL input"])
        }

        do {
            let (data, _) = try await session.data(from: url)
            markCompleted()
            return ["data": data]
        } catch {
            markFailed()
            throw error
        }
    }
}
