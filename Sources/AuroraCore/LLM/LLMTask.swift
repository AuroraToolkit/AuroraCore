//
//  LLMTask.swift
//  
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/// A task that interacts with an LLM service as part of its execution.
public class LLMTask: WorkflowTask {
    private let llmService: LLMServiceProtocol
    private let request: LLMRequest

    public init(name: String, description: String, inputs: [String: Any?] = [:], llmService: LLMServiceProtocol, request: LLMRequest, maxRetries: Int = 0) {
        self.llmService = llmService
        self.request = request
        super.init(name: name, description: description, inputs: inputs, maxRetries: maxRetries)
    }

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
