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

    // Workflow-related functions

    /// Starts the workflow execution by triggering the first or current task and proceeds sequentially.
    func start() async

    /// Retrieves the current workflow object.
    func getWorkflow() -> WorkflowProtocol

    /// Retrieves the current workflow state.
    func getWorkflowState() -> WorkflowState

    /// Evaluates and updates the current state of the workflow based on the status of its tasks.
    func evaluateState()

    /// Stops the workflow by marking it as stopped.
    func stopWorkflow()

    /// Retrieves the current task index in the workflow.
    func getCurrentTaskIndex() -> Int

    // Task-related functions

    /// Executes the current task in the workflow, checks required inputs, and updates the task state.
    func executeCurrentTask() async

    /// Completes the current task and progresses to the next task if available.
    func completeTask(_ task: WorkflowTaskProtocol) async

    /// Handles a task failure and determines whether to retry the task or stop the workflow.
    func handleTaskFailure(for task: WorkflowTaskProtocol) async
}

/**
 A concrete implementation of the `WorkflowManager` protocol, responsible for managing and executing a workflow.
 */
public class WorkflowManager: WorkflowManagerProtocol {
    public var workflow: WorkflowProtocol
    public let logger = Logger(subsystem: "com.mutantsoup.AuroraCore", category: "WorkflowManager")

    /**
     Initializes the workflow manager with a specific workflow.

     - Parameter workflow: The workflow that the manager will execute.
     */
    public init(workflow: WorkflowProtocol) {
        self.workflow = workflow
    }

    // Workflow-related functions
    public func start() async {
        guard workflow.state.isNotStarted || workflow.state.isInProgress else {
            logger.log("Cannot start workflow. Current state: \(String(describing: self.workflow.state))")
            return
        }

        await executeCurrentTask()
    }

    public func getWorkflow() -> WorkflowProtocol {
        return workflow
    }

    public func getWorkflowState() -> WorkflowState {
        return workflow.state
    }

    public func evaluateState() {
        workflow.evaluateState()
    }

    public func stopWorkflow() {
        guard workflow.state.isInProgress else {
            logger.log("Workflow already stopped or completed.")
            return
        }

        workflow.markStopped()
        logger.log("Workflow has been stopped.")
    }

    public func getCurrentTaskIndex() -> Int {
        return workflow.currentTaskIndex
    }

    // Task-related functions
    public func executeCurrentTask() async {
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
            await completeTask(updatedTask)
        } else {
            logger.log("Required inputs not present for task: \(task.name)")
            await handleTaskFailure(for: task)
        }
    }

    public func completeTask(_ task: WorkflowTaskProtocol) async {
        var updatedTask = task
        updatedTask.markCompleted(withOutputs: task.outputs)  // Pass the current outputs
        workflow.updateTask(updatedTask, at: workflow.currentTaskIndex)

        logger.log("Task \(task.name) completed with outputs: \(updatedTask.outputs)")

        if workflow.currentTaskIndex + 1 < workflow.tasks.count {
            workflow.currentTaskIndex += 1
            await executeCurrentTask()
        } else {
            workflow.tryMarkCompleted()
            logger.log("Workflow completed.")
        }
    }

    public func handleTaskFailure(for task: WorkflowTaskProtocol) async {
        if task.retryCount < task.maxRetries {
            var updatedTask = task
            updatedTask.incrementRetryCount()
            workflow.updateTask(updatedTask, at: workflow.currentTaskIndex)
            logger.log("Retrying task \(updatedTask.name). Retry \(updatedTask.retryCount) of \(updatedTask.maxRetries).")
            await executeCurrentTask()
        } else {
            var failedTask = task
            failedTask.markFailed()
            workflow.updateTask(failedTask, at: workflow.currentTaskIndex)
            workflow.markFailed(retryCount: failedTask.retryCount)
            logger.log("Task \(failedTask.name) failed after \(failedTask.maxRetries) retries. Stopping workflow.")
        }
    }
}