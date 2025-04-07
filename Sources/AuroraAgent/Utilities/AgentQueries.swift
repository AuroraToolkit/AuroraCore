//
//  AgentQueries.swift
//  AuroraAgent
//
//  Created by Dan Murrell Jr on 3/24/25.
//

import Foundation
import AuroraCore
import AuroraLLM
import AuroraTaskLibrary

extension Agent {
    /**
     Processes a query using a QueryTask and returns the LLM's response.
     
     If an optional `AgentMemory` instance is provided, the query and response are recorded in that memory.
     
     - Parameters:
       - query: The query string to process.
       - llmService: The LLM service to use for processing the query.
       - maxTokens: The maximum number of tokens for the response (default is 500).
       - systemPrompt: A custom system prompt for setting the LLM context (default is "You are a helpful assistant.").
       - memory: An optional `AgentMemory` instance. If not provided, no memory entry is recorded.
     
     - Returns: The response text from the LLM.
     */
    public func query(_ query: String,
                      using llmService: LLMServiceProtocol,
                      maxTokens: Int = 500,
                      systemPrompt: String = "You are a helpful assistant.",
                      memory: AgentMemory? = nil) async throws -> String {
        // Create a QueryTask using our new implementation.
        let queryTask = QueryTask(
            query: query,
            llmService: llmService,
            maxTokens: maxTokens,
            systemPrompt: systemPrompt
        )

        // Use provided memory or fall back to the agent's own memory.
        let memoryToUse = memory ?? self.memory

        // Generate a unique workflow name.
        let uuid = UUID().uuidString
        let workflowName = "Agent Query Workflow_\(uuid)"
        let workflowDescription = "Agent query, \(query.prefix(25))."

        // Build a simple workflow that executes the query task.
        var workflow = Workflow(
            name: workflowName,
            description: workflowDescription
        ) {
            queryTask.toComponent()
        }
        
        // Execute the workflow.
        await workflow.start()
        
        // Retrieve the response from the workflow outputs.
        guard let response = workflow.outputs["response"] as? String else {
            throw NSError(domain: "QueryTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to obtain response for query."])
        }
        
        // Record the query and response in memory.
        await memoryToUse.addQuery(query, response: response)

        return response
    }
}
