//
//  ExecutionTimer.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 12/29/24.
//

import Foundation

/**
    A simple timer for measuring the execution time of code blocks.
 */
public class ExecutionTimer {
    private var startTime: Date?
    private var endTime: Date?

    /**
     Starts the timer and returns self for chaining.
        - Returns: The timer instance.
     */
    @discardableResult
    public func start() -> Self {
        startTime = Date()
        return self
    }

    /**
        Stops the timer.
     */
    public func stop() {
        endTime = Date()
    }

    /**
        The duration as calculated as the difference between the start and end times.
     - Returns: The duration in seconds, or `nil` if the timer hasn't been started or stopped
     */
    public var duration: TimeInterval? {
        guard let startTime = startTime, let endTime = endTime else {
            return nil
        }
        return endTime.timeIntervalSince(startTime)
    }

    /**
        Resets the timer by setting the start and end times to `nil`.
     */
    public func reset() {
        startTime = nil
        endTime = nil
    }
}
