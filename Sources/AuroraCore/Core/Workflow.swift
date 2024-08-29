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
    /// The collection of tasks within this workflow.
    var tasks: [TaskProtocol] { get set }

    /// The current state of the workflow.
    var state: WorkflowState { get set }

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
    func addTask(_ task: TaskProtocol)

    /// Updates a task at a given index in the workflow.
    func updateTask(_ task: TaskProtocol, at index: Int)
}

/**
 A concrete implementation of the `WorkflowProtocol`, responsible for executing and managing tasks in a workflow.
 */
public class Workflow: WorkflowProtocol {
    public var tasks: [TaskProtocol]
    public var state: WorkflowState = .notStarted
    public var currentTaskIndex: Int = 0
    public let logger = Logger(subsystem: "com.mutantsoup.AuroraCore", category: "Workflow")

    /**
     Initializes a new workflow with a specified name, description, and tasks.

     - Parameters:
        - tasks: An optional array of tasks to be added to the workflow (default is an empty array).
     */
    public init(tasks: [TaskProtocol] = []) {
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
}
