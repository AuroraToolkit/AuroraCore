//
//  MockWorkflow.swift
//
//
//  Created by Dan Murrell Jr on 8/30/24.
//

import Foundation
@testable import AuroraCore

class MockWorkflow: WorkflowProtocol {
    var id: UUID = UUID()
    var name: String
    var description: String
    var tasks: [WorkflowTaskProtocol]
    var currentTaskIndex: Int = 0
    var state: WorkflowState = .notStarted

    init(name: String, description: String, tasks: [WorkflowTaskProtocol] = []) {
        self.name = name
        self.description = description
        self.tasks = tasks
    }

    internal func setState(_ state: WorkflowState) {
        self.state = state
    }

    func addTask(_ task: WorkflowTaskProtocol) {
        tasks.append(task)
    }

    func updateTask(_ task: WorkflowTaskProtocol, at index: Int) {
        guard index < tasks.count else { return }
        tasks[index] = task
    }

    @discardableResult
    func tryMarkCompleted() -> Bool {
        if tasks.allSatisfy({ $0.status == .completed }) {
            state = .completed(Date())
            return true
        }
        return false
    }

    func markStopped() {
        state = .stopped(Date())
    }

    func markFailed(retryCount: Int) {
        state = .failed(Date(), retryCount)
    }

    func isCompleted() -> Bool {
        return state.isCompleted
    }

    func resetWorkflow() {
        tasks.indices.forEach { tasks[$0].resetTask() }
        currentTaskIndex = 0
        state = .notStarted
    }

    func evaluateState() {
        if state.isStopped {
            // If the workflow has been manually stopped, do not change its state
            return
        }

        if tasks.allSatisfy({ $0.status == .pending }) {
            state = .notStarted
        } else if tasks.allSatisfy({ $0.status == .completed }) && !state.isCompleted {
            state = .completed(Date())
        } else if tasks.contains(where: { $0.status == .failed && !$0.canRetry() }) && !state.isFailed {
            state = .failed(Date(), 0) // Assuming 0 for the failed retry count
        } else {
            state = .inProgress
        }
    }

    func activeTasks() -> [WorkflowTaskProtocol] {
        return tasks.filter { $0.status == .pending || $0.status == .inProgress }
    }

    func completedTasks() -> [WorkflowTaskProtocol] {
        return tasks.filter { $0.status == .completed }
    }
}
