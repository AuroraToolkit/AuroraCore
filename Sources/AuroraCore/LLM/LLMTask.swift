//
//  LLMTask.swift
//  
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/**
 `LLMTask` sends a prompt to a Large Language Model (LLM) service and returns a response.

 - **Inputs**
    - `llmRequest`: The request object containing the prompt and configuration for the LLM service.
 - **Outputs**
    - `response`: The response from the LLM service.

 This task is designed to be part of a workflow where the result from an LLM is used in further tasks.

 - Note: This class works with any service that conforms to `LLMServiceProtocol`.
 */
public class LLMTask: WorkflowComponent {
    /// The wrapped task.
    private let task: Workflow.Task

    /// The LLM service used for sending requests and receiving responses.
    private let llmService: LLMServiceProtocol

    /**
     Initializes a new `LLMTask`.

     - Parameters:
        - name: The name of the task.
        - description: A detailed description of the task.
        - llmService: The LLM service that will handle the request.
        - request: The `LLMRequest` containing the prompt and configuration for the LLM service.
     */
    public init(
        name: String? = nil,
        description: String? = nil,
        llmService: LLMServiceProtocol,
        request: LLMRequest? = nil,
        inputs: [String: Any?] = [:]
    ) {
        // Merge direct parameters into inputs
        var mergedInputs = inputs
        if let request {
            mergedInputs["request"] = request
        }

        self.llmService = llmService
        self.task = Workflow.Task(
            name: name,
            description: description ?? "Send a prompt to the LLM service",
            inputs: mergedInputs
        ) { inputs in
            guard let request = inputs["request"] as? LLMRequest else {
                throw NSError(
                    domain: "LLMTask",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "LLMRequest is missing."]
                )
            }

            do {
                let response = try await llmService.sendRequest(request)
                return ["response": response.text]
            } catch {
                throw error
            }
        }
    }

    /// Converts this `FetchURLTask` to a `Workflow.Component`.
    public func toComponent() -> Workflow.Component {
        .task(task)
    }
}
