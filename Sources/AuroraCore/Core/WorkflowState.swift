//
//  WorkflowState.swift
//
//
//  Created by Dan Murrell Jr on 8/29/24.
//

import Foundation

/**
 `WorkflowState` represents the various states a workflow can be in during its lifecycle.

 - notStarted: The workflow has been defined but not yet started.
 - inProgress: The workflow is currently being executed.
 - stopped: The workflow has been manually stopped.
 - completed: The workflow has successfully completed all tasks.
 - failed: The workflow has failed after exhausting all retries for a task.
 */
public enum WorkflowState: Equatable {
    case notStarted
    case inProgress
    case stopped(Date)
    case completed(Date)
    case failed(Date, Int) // failed date, retry count

    // Computed properties to check state
    public var isNotStarted: Bool {
        if case .notStarted = self { return true }
        return false
    }

    public var isInProgress: Bool {
        if case .inProgress = self { return true }
        return false
    }

    public var isStopped: Bool {
        if case .stopped = self { return true }
        return false
    }

    public var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    public var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
