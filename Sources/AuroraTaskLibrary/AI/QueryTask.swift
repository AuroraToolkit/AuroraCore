//
//  QueryTask.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 3/24/25.
//

import Foundation
import AuroraCore
import AuroraLLM

/**
 `QueryTask` sends a query to an LLM service and returns the response.

 This task is intended for use within an Agent to process a user's query.
 It leverages the existing Workflow.Task infrastructure.

 - **Inputs**
    - Additional inputs may be provided.
 - **Outputs**
    - `response`: The text response from the LLM.
 */
public class QueryTask: WorkflowComponent {
    /// The wrapped workflow task.
    private let task: Workflow.Task

    /**
     Initializes a new `QueryTask`.

     - Parameters:
         - name: An optional name for the task. Defaults to `"LLMQueryTask"`.
         - description: An optional description for the task. Defaults to `"Sends a query to the LLM service and returns the response."`
         - query: The query string to be sent to the LLM.
         - llmService: The LLM service to use for processing the query.
         - maxTokens: The maximum number of tokens for the response. Defaults to 500.
         - systemPrompt: A custom system prompt to set the context for the LLM. Defaults to `"You are a helpful assistant."`
         - inputs: Additional inputs (if needed). Defaults to an empty dictionary.
     */
    public init(name: String? = nil,
                description: String? = nil,
                query: String,
                llmService: LLMServiceProtocol,
                maxTokens: Int = 500,
                systemPrompt: String = "You are a helpful assistant.",
                inputs: [String: Any?] = [:]) {
        let taskName = name ?? "LLMQueryTask"
        let taskDescription = description ?? "Sends a query to the LLM service and returns the response."
        
        self.task = Workflow.Task(
            name: taskName,
            description: taskDescription,
            inputs: inputs
        ) { inputs in
            let request = LLMRequest(
                messages: [
                    LLMMessage(role: .system, content: systemPrompt),
                    LLMMessage(role: .user, content: query)
                ],
                maxTokens: maxTokens
            )
            let response = try await llmService.sendRequest(request)
            return ["response": response.text]
        }
    }

    /// Conforms to WorkflowComponent by returning the wrapped task as a component.
    public func toComponent() -> Workflow.Component {
        return .task(task)
    }
}
