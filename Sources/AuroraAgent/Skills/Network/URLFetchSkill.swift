//
//  URLFetchSkill.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 3/26/25.
//

import Foundation
import AuroraCore
import AuroraTaskLibrary

/**
    A simple agent skill that fetches content from a URL.

    This skill fetches the content at a specified URL and returns it as a string.
 */
public struct URLFetchSkill: AgentSkill {
    public var id: UUID
    public let name: String
    public let description: String
    public let url: String

    /**
        Initializes a new URLFetchSkill with the specified URL, name, and description.

        - Parameters:
            - url: The URL to fetch.
            - name: The name of the skill (default is "URL Fetch Skill").
            - description: A description of the skill.
     */
    public init(
        url: String,
        name: String = "URL Fetch Skill",
        description: String = "Fetches content from a URL"
    ) {
        self.id = UUID()
        self.url = url
        self.name = name
        self.description = description
    }

    /**
        Executes the skill by fetching the content at the specified URL.

        - Parameter query: An optional query string (ignored in this simple skill).
        - Parameter memory: An optional memory object (ignored in this simple skill).

        - Returns: The textual content fetched from the URL.
     */
    public func execute(query: String, memory: AgentMemory?) async throws -> String {
        // Build a workflow that includes a FetchURLTask.
        var workflow = Workflow(name: "URLFetchWorkflow", description: "Workflow to fetch URL data") {
            FetchURLTask(name: "FetchURL", url: self.url)
        }

        // Execute the workflow.
        await workflow.start()

        // Extract the fetched data from the workflow outputs.
        guard let data = workflow.outputs["FetchURL.data"] as? Data,
              let content = String(data: data, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        return content
    }
}
