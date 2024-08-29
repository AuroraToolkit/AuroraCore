//
//  WorkflowManager.swift
//
//
//  Created by Dan Murrell Jr on 8/29/24.
//

import Foundation
import os.log

/**
 A protocol defining the essential properties and behaviors of a workflow manager, responsible for executing and managing workflows.
 */
public protocol WorkflowManagerProtocol {
    /// The workflow that the manager will execute.
    var workflow: WorkflowProtocol { get set }

    /// Logger instance for logging workflow events.
    var logger: Logger { get }

    /// Starts the workflow execution by triggering the first or current task and proceeds sequentially.
    func start()

    /// Evaluates and updates the current state of the workflow based on the status of its tasks.
    func evaluateState()

    /// Executes the current task in the workflow, checks required inputs, and updates the task state.
    func executeCurrentTask()

    /// Completes the current task and progresses to the next task if available.
    func completeTask(_ task: TaskProtocol)

    /// Handles a task failure and determines whether to retry the task or stop the workflow.
    func handleTaskFailure(for task: TaskProtocol)

    /// Stops the workflow by marking it as stopped.
    func stopWorkflow()

    /// Retrieves the current workflow state.
    func getWorkflowState() -> WorkflowState

    /// Retrieves the current workflow object.
    func getWorkflow() -> WorkflowProtocol
}

/**
 A concrete implementation of the `WorkflowManager` protocol, responsible for managing and executing a workflow.
 */
public class WorkflowManager: WorkflowManagerProtocol {
    public var workflow: Workflow
    public var logger = Logger(subsystem: "com.mutantsoup.AuroraCore", category: "WorkflowManager")

    /**
     Initializes the workflow manager with a specific workflow.

     - Parameter workflow: The workflow that the manager will execute.
     */
    public init(workflow: Workflow) {
        self.workflow = workflow
    }

    public func start() {
        guard workflow.state.isNotStarted || workflow.state.isInProgress else {
            logger.log("Cannot start workflow. Current state: \(String(describing: self.workflow.state))")
            return
        }

        executeCurrentTask()
    }

    public func evaluateState() {
        if workflow.tasks.allSatisfy({ $0.status == .pending }) {
            workflow.state = .notStarted
        } else if workflow.tasks.allSatisfy({ $0.status == .completed }) && !workflow.state.isCompleted {
            workflow.state = .completed(Date())
        } else if workflow.tasks.contains(where: { $0.status == .failed && !$0.canRetry() }) && !workflow.state.isFailed {
            workflow.state = .failed(Date(), 0) // Assuming 0 for the failed retry count
        } else if workflow.state.isStopped {
            return // Workflow has been manually stopped, do not change its state
        } else {
            workflow.state = .inProgress
        }
    }

    public func executeCurrentTask() {
        guard workflow.state.isNotStarted || workflow.state.isInProgress else {
            logger.log("Workflow is not in progress.")
            return
        }

        // Ensure there are tasks to execute
        guard workflow.currentTaskIndex < workflow.tasks.count else {
            logger.log("No tasks to execute in the workflow.")
            workflow.tryMarkCompleted() // Mark the workflow as completed if no tasks
            return
        }

        let task = workflow.tasks[workflow.currentTaskIndex]

        if task.hasRequiredInputs() {
            var updatedTask = task
            updatedTask.markInProgress()
            completeTask(updatedTask)
        } else {
            logger.log("Required inputs not present for task: \(task.name)")
            handleTaskFailure(for: task)
        }
    }

    public func completeTask(_ task: TaskProtocol) {
        var updatedTask = task
        updatedTask.markCompleted()
        workflow.updateTask(updatedTask, at: workflow.currentTaskIndex)

        logger.log("Task \(task.name) completed with outputs: \(updatedTask.outputs)")

        if workflow.currentTaskIndex + 1 < workflow.tasks.count {
            workflow.currentTaskIndex += 1
            executeCurrentTask()
        } else {
            workflow.tryMarkCompleted()
            logger.log("Workflow completed.")
        }
    }

    public func handleTaskFailure(for task: Task) {
        if task.retryCount < task.maxRetries {
            var updatedTask = task
            updatedTask.incrementRetryCount() // Increment the retry count
            workflow.updateTask(updatedTask, at: workflow.currentTaskIndex) // Update the task in the workflow
            logger.log("Retrying task \(updatedTask.name). Retry \(updatedTask.retryCount) of \(updatedTask.maxRetries).")
            executeCurrentTask() // Re-execute the current task
        } else {
            var failedTask = task
            failedTask.markFailed()
            workflow.updateTask(failedTask, at: workflow.currentTaskIndex) // Update the task in the workflow
            workflow.markFailed(retryCount: failedTask.retryCount)
            logger.log("Task \(failedTask.name) failed after \(failedTask.maxRetries) retries. Stopping workflow.")
        }
    }

    public func stopWorkflow() {
        guard workflow.state.isInProgress else {
            logger.log("Workflow already stopped or completed.")
            return
        }

        workflow.markStopped()
        logger.log("Workflow has been stopped.")
    }

    public func getWorkflowState() -> WorkflowState {
        return workflow.state
    }

    public func getWorkflow() -> Workflow {
        return workflow
    }
}
