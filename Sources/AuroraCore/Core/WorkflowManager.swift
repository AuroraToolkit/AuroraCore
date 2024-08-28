//
//  WorkflowManager.swift
//
//
//  Created by Dan Murrell Jr on 8/25/24.
//

import Foundation
import os.log

/**
 `WorkflowManager` is responsible for managing the execution of workflows and their tasks in a linear sequence.
 It tracks the state of the workflow, handles task execution, manages inputs and outputs, and gracefully handles errors and retries.
 */
public class WorkflowManager {
    /// The workflow that the manager will execute.
    private var workflow: Workflow

    /// The index of the current task being executed.
    private var currentTaskIndex: Int = 0

    /// Logger instance for logging workflow events.
    private let logger = Logger(subsystem: "com.mutantsoup.AuroraCore", category: "WorkflowManager")

    /**
     Initializes the workflow manager with a specific workflow.

     - Parameter workflow: The workflow that the manager will execute.
     */
    public init(workflow: Workflow) {
        self.workflow = workflow
    }

    /**
     Starts the workflow execution by triggering the first or current task and proceeds sequentially.
     Ensures the workflow is not started or in progress before attempting to execute tasks.
     */
    public func start() {
        guard workflow.state == .notStarted || workflow.state == .inProgress else {
            logger.log("Cannot start workflow. Current state: \(String(describing: self.workflow.state))")
            return
        }

        executeCurrentTask()
    }

    /**
     Evaluates and updates the current state of the workflow based on the status of its tasks.
     - If no tasks have been started, the workflow remains in the `.notStarted` state.
     - If all tasks are completed, the workflow is marked as `completed`.
     - If there are any failed tasks without retries left, the workflow is marked as `failed`.
     - If the workflow has been stopped, its state remains `stopped`.
     - Otherwise, the workflow remains `inProgress`.
     */
    public func evaluateState() {
        if workflow.tasks.allSatisfy({ $0.status == .pending }) {
            workflow.state = .notStarted
        } else if workflow.tasks.allSatisfy({ $0.status == .completed }) && !workflow.state.isCompleted {
            workflow.state = .completed(Date())
        } else if workflow.tasks.contains(where: { $0.status == .failed && !$0.canRetry() }) && !workflow.state.isFailed {
            workflow.state = .failed(Date(), 0) // Assuming 0 for the failed retry count
        } else if workflow.state == .stopped(Date()) && !workflow.state.isStopped {
            return // Workflow has been manually stopped, do not change its state
        } else {
            workflow.state = .inProgress
        }
    }

    /**
     Executes the current task in the workflow, checks required inputs, and updates the task state.
     Ensures the workflow is in progress before executing the current task.
     */
    internal func executeCurrentTask() {
        guard workflow.state == .notStarted || workflow.state == .inProgress else {
            logger.log("Workflow is not in progress.")
            return
        }

        // Ensure there are tasks to execute
        guard currentTaskIndex < workflow.tasks.count else {
            logger.log("No tasks to execute in the workflow.")
            workflow.tryMarkCompleted() // Mark the workflow as completed if no tasks
            return
        }

        let task = workflow.tasks[currentTaskIndex]

        if task.hasRequiredInputs() {
            var updatedTask = task
            updatedTask.markInProgress()
            completeTask(updatedTask)
        } else {
            logger.log("Required inputs not present for task: \(task.name)")
            handleTaskFailure(for: task)
        }
    }

    /**
     Completes the current task and progresses to the next task if available.
     Marks the workflow as completed if all tasks have been executed.

     - Parameter task: The task that has been successfully completed.
     */
    private func completeTask(_ task: Task) {
        var updatedTask = task
        updatedTask.markCompleted()
        workflow.updateTask(updatedTask, at: currentTaskIndex)

        logger.log("Task \(task.name) completed with outputs: \(updatedTask.outputs)")

        if currentTaskIndex + 1 < workflow.tasks.count {
            currentTaskIndex += 1
            executeCurrentTask()
        } else {
            workflow.tryMarkCompleted()
            logger.log("Workflow completed.")
        }
    }

    /**
     Handles a task failure and determines whether to retry the task or stop the workflow.
     If retries are available, the task is retried. Otherwise, the workflow is marked as failed.

     - Parameter task: The task that failed.
     */
    internal func handleTaskFailure(for task: Task) {
        if task.retryCount < task.maxRetries {
            var updatedTask = task
            updatedTask.incrementRetryCount() // Increment the retry count
            workflow.updateTask(updatedTask, at: currentTaskIndex) // Update the task in the workflow
            logger.log("Retrying task \(updatedTask.name). Retry \(updatedTask.retryCount) of \(updatedTask.maxRetries).")
            executeCurrentTask() // Re-execute the current task
        } else {
            var failedTask = task
            failedTask.markFailed()
            workflow.updateTask(failedTask, at: currentTaskIndex) // Update the task in the workflow
            workflow.markFailed(retryCount: failedTask.retryCount)
            logger.log("Task \(failedTask.name) failed after \(failedTask.maxRetries) retries. Stopping workflow.")
        }
    }

    /**
     Stops the workflow by marking it as stopped. Ensures that the workflow is in progress before stopping it.
     */
    public func stopWorkflow() {
        guard workflow.state == .notStarted || workflow.state == .inProgress else {
            logger.log("Workflow already stopped or completed.")
            return
        }

        workflow.markStopped()
        logger.log("Workflow has been stopped.")
    }

    /**
     Retrieves the current workflow state.

     - Returns: The current state of the workflow as a `WorkflowState` enum.
     */
    public func getWorkflowState() -> WorkflowState {
        return workflow.state
    }

    /**
     Retrieves the current workflow object.

     - Returns: The current `Workflow` object.
     */
    public func getWorkflow() -> Workflow {
        return workflow
    }

    /**
     Retrieves the current task index being executed in the workflow.

     - Returns: The current index of the task being executed.
     */
    public func getCurrentTaskIndex() -> Int {
        return currentTaskIndex
    }
}
