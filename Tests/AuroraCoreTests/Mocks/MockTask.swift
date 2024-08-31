//
//  MockTask.swift
//  
//
//  Created by Dan Murrell Jr on 8/31/24.
//

import Foundation
@testable import AuroraCore

class MockTask: TaskProtocol {
    var id = UUID()
    var name: String
    var description: String
    var status: TaskStatus
    var inputs: [String: Any?]
    var outputs: [String: Any] = [:]
    var creationDate: Date = Date()
    var completionDate: Date?
    var retryCount: Int
    var maxRetries: Int
    var hasRequiredInputsValue: Bool

    init(
        name: String,
        description: String,
        status: TaskStatus = .pending,
        inputs: [String: Any?] = [:],
        retryCount: Int = 0,
        maxRetries: Int = 3,
        hasRequiredInputsValue: Bool = true
    ) {
        self.name = name
        self.description = description
        self.status = status
        self.inputs = inputs
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.hasRequiredInputsValue = hasRequiredInputsValue
    }

    func markCompleted(withOutputs outputs: [String: Any] = [:]) {
        self.status = .completed
        self.completionDate = Date()
        self.outputs = outputs
    }

    func markInProgress() {
        self.status = .inProgress
    }

    func markFailed() {
        self.status = .failed
    }

    func resetTask() {
        self.status = .pending
        self.completionDate = nil
        self.outputs = [:]
        self.retryCount = 0
    }

    func incrementRetryCount() {
        retryCount += 1
    }

    func canRetry() -> Bool {
        return retryCount < maxRetries
    }

    func hasRequiredInputs() -> Bool {
        return hasRequiredInputsValue
    }
}
