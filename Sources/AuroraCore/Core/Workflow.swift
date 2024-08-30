//
//  Workflow.swift
//
//
//  Created by Dan Murrell Jr on 8/29/24.
//

import Foundation
import os.log

/**
 A protocol defining the essential properties and behaviors of a workflow, responsible for executing and managing tasks.
 */
public protocol WorkflowProtocol {
       /// Unique identifier for the task.
    var id: UUID { get }

    /// Name of the task.
    var name: String { get }

    /// A detailed description of the task.
    var description: String { get }

    /// The collection of tasks within this workflow.
    var tasks: [TaskProtocol] { get }

    /// The current state of the workflow.
    var state: WorkflowState { get }

    /// Index of the currently executing task.
    var currentTaskIndex: Int { get set }

    /// Logger instance for logging workflow events.
    var logger: Logger { get }

    /// Attempts to mark the workflow as completed.
    @discardableResult
    func tryMarkCompleted() -> Bool

    /// Updates the state of the workflow to `stopped`.
    func markStopped()

    /// Updates the state of the workflow to `failed`.
    func markFailed(retryCount: Int)

    /// Helper method to check if the workflow is completed.
    func isCompleted() -> Bool

    /// Resets the workflow to its initial state.
    func resetWorkflow()

    /// Adds a new task to the workflow.
    mutating func addTask(_ task: TaskProtocol)

    /// Updates a task at a given index in the workflow.
    mutating func updateTask(_ task: TaskProtocol, at index: Int)

    /// Evaluates the state of the workflow based on the status of its tasks.
    mutating func evaluateState()

    /// Returns an array of tasks that are currently active (pending or in progress).
    func activeTasks() -> [TaskProtocol]

    /// Returns an array of tasks that have been completed.
    func completedTasks() -> [TaskProtocol]
}

/**
 A concrete implementation of the `WorkflowProtocol`, responsible for executing and managing tasks in a workflow.
 */
public class Workflow: WorkflowProtocol {
    public let id: UUID
    public let name: String
    public let description: String
    public private(set) var tasks: [TaskProtocol]
    public private(set) var state: WorkflowState = .notStarted
    public var currentTaskIndex: Int = 0
    public let logger = Logger(subsystem: "com.mutantsoup.AuroraCore", category: "Workflow")

    /**
     Initializes a new workflow with a specified name, description, and tasks.

     - Parameters:
        - tasks: An optional array of tasks to be added to the workflow (default is an empty array).
     */
    public init(name: String, description: String, tasks: [TaskProtocol] = []) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.tasks = tasks
    }

    @discardableResult
    public func tryMarkCompleted() -> Bool {
        let activeTasksExist = tasks.contains { $0.status == .pending || $0.status == .inProgress }

        if !activeTasksExist {
            self.state = .completed(Date())
            return true
        } else {
            logger.log("Cannot mark workflow as completed. There are still active tasks.")
            return false
        }
    }

    public func markStopped() {
        self.state = .stopped(Date())
    }

    public func markFailed(retryCount: Int) {
        self.state = .failed(Date(), retryCount)
    }

    public func isCompleted() -> Bool {
        if case .completed(_) = state {
            return true
        }
        return false
    }

    public func resetWorkflow() {
        tasks.indices.forEach { tasks[$0].resetTask() }
        self.currentTaskIndex = 0
        self.state = .notStarted
    }

    public func addTask(_ task: TaskProtocol) {
        tasks.append(task)
    }

    /**
     Updates a task at a given index in the workflow.

     - Parameters:
        - task: The updated task to be placed at the given index.
        - index: The index of the task to be updated.
     */
    public func updateTask(_ task: TaskProtocol, at index: Int) {
        guard index >= 0 && index < tasks.count else { return }
        tasks[index] = task
    }

    /**
     Executes the next task in the workflow that is in the `pending` state.
     */
    public func executeNextTask() {
        guard currentTaskIndex < tasks.count else {
            tryMarkCompleted()
            return
        }

        var task = tasks[currentTaskIndex]
        task.markInProgress()

        if task.hasRequiredInputs() {
            completeCurrentTask()
        } else {
            handleTaskFailure()
        }
    }

    /**
     Completes the current task, processes its outputs, and proceeds to the next task.
     */
    private func completeCurrentTask() {
        tasks[currentTaskIndex].markCompleted(withOutputs: tasks[currentTaskIndex].outputs)

        if currentTaskIndex + 1 < tasks.count {
            currentTaskIndex += 1
            executeNextTask()
        } else {
            tryMarkCompleted()
        }
    }

    /**
     Handles the failure of the current task. The workflow may either stop or attempt to recover based on retry logic.

     If the task has retries left, it will be retried. Otherwise, the workflow will be marked as failed.
     */
    private func handleTaskFailure() {
        var failedTask = tasks[currentTaskIndex]

        if failedTask.canRetry() {
            failedTask.incrementRetryCount()
            logger.log("Retrying task \(failedTask.name). Attempt \(failedTask.retryCount) of \(failedTask.maxRetries).")

            failedTask.resetTask()
            updateTask(failedTask, at: currentTaskIndex)
            executeNextTask()
        } else {
            failedTask.markFailed()
            updateTask(failedTask, at: currentTaskIndex)
            logger.log("Task \(failedTask.name) failed after \(failedTask.retryCount) retries. Stopping workflow.")
            markFailed(retryCount: failedTask.retryCount)
        }
    }

    public func evaluateState() {
        if tasks.allSatisfy({ $0.status == .pending }) {
            state = .notStarted
        } else if tasks.allSatisfy({ $0.status == .completed }) && !state.isCompleted {
            state = .completed(Date())
        } else if tasks.contains(where: { $0.status == .failed && !$0.canRetry() }) && !state.isFailed {
            state = .failed(Date(), 0) // Assuming 0 for the failed retry count
        } else if state.isStopped {
            return // Workflow has been manually stopped, do not change its state
        } else {
            state = .inProgress
        }
    }

    public func activeTasks() -> [TaskProtocol] {
        return tasks.filter { $0.status == .inProgress || $0.status == .pending }
    }

    public func completedTasks() -> [TaskProtocol] {
        return tasks.filter { $0.status == .completed }
    }
}
