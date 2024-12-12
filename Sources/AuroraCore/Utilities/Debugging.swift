//
//  Debugging.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/12/24.
//

import Foundation
import os

/**
    The `CustomLogger` class provides a centralized logging system for the app. It allows for logging messages at different severity levels and categories, as well as enabling or disabling debug logs.

    Usage:
    ```swift
    CustomLogger.shared.debug("Debug message", category: "MyCategory")
    CustomLogger.shared.info("Info message")
    CustomLogger.shared.error("Error message", category: "MyCategory")
    CustomLogger.shared.fault("Fault message")

    CustomLogger.shared.toggleDebugLogs(true)

    CustomLogger.shared.log(level: .info, "Custom log message", category: "MyCategory", metadata: ["key": "value"])
    ```
 */
final public class CustomLogger {
    static public let shared = CustomLogger()

    private var loggers: [String: Logger] = [:]
    private let loggerQueue = DispatchQueue(label: "com.mutantsoup.AuroraCore.loggerQueue")

#if DEBUG
    private var enableDebugLogs = true
#else
    private var enableDebugLogs = false
#endif

    private init() {}

    /// Retrieves or creates a logger for the specified category.
    /// - Parameter category: The category for the logger.
    /// - Returns: An instance of `Logger` for the specified category.
    func getLogger(for category: String) -> Logger {
        return loggerQueue.sync {
            if let logger = loggers[category] {
                return logger
            }
            let logger = Logger(subsystem: "com.mutantsoup.AuroraCore", category: category)
            loggers[category] = logger
            return logger
        }
    }

    /**
     Toggles the global debug logs on or off.
     - Parameter enabled: A boolean value indicating whether debug logs should be enabled.
     */
    public func toggleDebugLogs(_ enabled: Bool) {
        loggerQueue.sync {
            enableDebugLogs = enabled
        }
    }

    /**
     Logs a message to the console with optional metadata.
     - Parameters:
       - level: The severity level of the log message (`.debug`, `.info`, `.error`, `.fault`).
       - message: The message to log.
       - category: The category for the log message. Defaults to `"Unspecified"`.
       - metadata: A dictionary of key-value pairs providing additional context (optional).
     */
    public func log(
        level: OSLogType,
        _ message: String,
        category: String = "Unspecified",
        metadata: [String: String] = [:]
    ) {
        guard level != .debug || enableDebugLogs else { return } // Skip debug logs if disabled
        let logger = getLogger(for: category)

        // Add metadata if available
        if metadata.isEmpty {
            logger.log(level: level, "\(message, privacy: .public)")
        } else {
            let metadataDescription = metadata.map { "\($0.key): \($0.value)" }
                .joined(separator: ", ")
            logger.log(level: level, "\(message) [\(metadataDescription)]")
        }
    }

    // MARK: - Helper Methods

    /// Logs a debug-level message.
    public func debug(_ message: String, category: String = "Unspecified", metadata: [String: String] = [:]) {
        log(level: .debug, message, category: category, metadata: metadata)
    }

    /// Logs an info-level message.
    public func info(_ message: String, category: String = "Unspecified", metadata: [String: String] = [:]) {
        log(level: .info, message, category: category, metadata: metadata)
    }

    /// Logs an error-level message.
    public func error(_ message: String, category: String = "Unspecified", metadata: [String: String] = [:]) {
        log(level: .error, message, category: category, metadata: metadata)
    }

    /// Logs a fault-level message.
    public func fault(_ message: String, category: String = "Unspecified", metadata: [String: String] = [:]) {
        log(level: .fault, message, category: category, metadata: metadata)
    }
}
