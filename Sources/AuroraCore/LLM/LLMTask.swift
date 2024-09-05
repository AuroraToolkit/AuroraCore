//
//  LLMTask.swift
//  
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/**
 The `LLMTask` class represents a workflow task that sends a prompt to a Language Learning Model (LLM) service
 and processes the response.

 This task is designed to be part of a workflow where the result from an LLM is used in further tasks.

 - Note: This class works with any service that conforms to `LLMServiceProtocol`.
 */
public class LLMTask: WorkflowTask {
    /**
     The LLM service used for sending requests and receiving responses.

     - Important: This must conform to the `LLMServiceProtocol`.
     */
    private let llmService: LLMServiceProtocol

    /**
     The request object containing the prompt and configuration for the LLM service.
     */
    private let request: LLMRequest

    /**
     Initializes a new `LLMTask`.

     - Parameters:
         - name: The name of the task.
         - description: A detailed description of the task.
         - prompt: The prompt that will be sent to the LLM service.
         - llmService: The LLM service that will handle the request.
     */
    public init(name: String, description: String, inputs: [String: Any?] = [:], llmService: LLMServiceProtocol, request: LLMRequest, maxRetries: Int = 0) {
        self.llmService = llmService
        self.request = request
        super.init(name: name, description: description, inputs: inputs, maxRetries: maxRetries)
    }

    /**
     Executes the `LLMTask` by sending the prompt to the connected LLM service.

     - Throws: An error if the LLM service fails to process the request.
     - Returns: The result of the request stored in `outputs`.
     */
    public override func execute() async throws {
        do {
            let response = try await llmService.sendRequest(request)
            markCompleted(withOutputs: ["response": response.text])
        } catch {
            markFailed()
            throw error
        }
    }
}
