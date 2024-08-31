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
    var tasks: [TaskProtocol]
    var currentTaskIndex: Int = 0
    var state: WorkflowState = .notStarted

    init(name: String, description: String, tasks: [TaskProtocol] = []) {
        self.name = name
        self.description = description
        self.tasks = tasks
    }

    func addTask(_ task: TaskProtocol) {
        tasks.append(task)
    }

    func updateTask(_ task: TaskProtocol, at index: Int) {
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
        if tasks.allSatisfy({ $0.status == .pending }) {
            state = .notStarted
        } else if tasks.allSatisfy({ $0.status == .completed }) {
            state = .completed(Date())
        } else if tasks.contains(where: { $0.status == .failed && !$0.canRetry() }) {
            state = .failed(Date(), 0) // Assuming 0 for the failed retry count
        } else if state.isStopped {
            return
        } else {
            state = .inProgress
        }
    }

    func activeTasks() -> [TaskProtocol] {
        return tasks.filter { $0.status == .pending || $0.status == .inProgress }
    }

    func completedTasks() -> [TaskProtocol] {
        return tasks.filter { $0.status == .completed }
    }
}
