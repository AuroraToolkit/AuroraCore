//
//  DualDomainRouter.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 4/15/25.
//

import Foundation
import AuroraCore

/**
    A struct representing a domain prediction with a label and confidence score.
 */
public struct DualDomainPrediction: Equatable {
    /// The predicted domain label.
    public let label: String
    /// The confidence score associated with the prediction.
    public let confidence: Double
}

/**
A domain router that combines two classifiers:

 - A **primary** router (default authority)
 - A **secondary** contrastive router (used to validate, challenge, or help resolve uncertain predictions)

 The router uses confidence thresholds and an optional fallback domain to resolve disagreements.
 */
public struct DualDomainRouter: LLMDomainRouterProtocol {

    /// The name of the router, used for logging and identification.
    public let name: String

    /// The list of valid domains this router recognizes.
    public let supportedDomains: [String]

    /// Optional confidence threshold to auto-resolve conflicts.
    /// If the difference in confidence exceeds this value, the higher-confidence result is used.
    public let confidenceThreshold: Double?

    /// If both classifiers return confidence scores below this threshold, fallback to this domain.
    public let fallbackDomain: String?

    /// Optional confidence threshold for the fallback domain.
    public let fallbackConfidenceThreshold: Double?

    /// If true, fallback predictions will be synthesized as "unknown" if `fallbackDomain` is unset instead of returning nil.
    public let allowSyntheticFallbacks: Bool

    /// The primary router, considered the default source of truth unless contradicted by confidence logic or conflict resolution.
    private let primary: LLMDomainRouterProtocol

    /// The secondary router, providing contrastive input to challenge or validate the primary router's prediction.
    private let secondary: LLMDomainRouterProtocol

    /**
    A closure provided by the developer to resolve domain prediction conflicts
    that cannot be automatically settled by confidence thresholds.

    This is the final fallback resolution step when:
     - The primary and secondary predictions differ
     - The confidence delta is below the resolution threshold
     - Neither prediction meets the fallback confidence threshold

    The closure receives the predicted domains (or `nil`) from both routers
    and should return a supported domain or `nil` if resolution is not possible.

    Examples:

        // Basic: Prefer primary if available, fallback to secondary
        resolve: { primary, secondary in
            return primary ?? secondary
        }

        // Custom logic: Favor 'technology' over 'health' in ties
        resolve: { primary, secondary in
            if primary == "health" && secondary == "technology" {
                return "technology"
            }
            return primary ?? secondary
        }
    */
    private let resolve: (_ primary: DualDomainPrediction?, _ secondary: DualDomainPrediction?) -> String?

    /// Shared logger instance.
    private let logger: CustomLogger?

    /// A logger for capturing conflicts between primary and secondary predictions in DualDomainRouter.
    private let conflictLogger: ConflictLoggingStrategy?
    /**
     Initializes a new `DualDomainRouter`.

     - Parameters:
        - name: The name of the router.
        - primary: The primary (default) router whose prediction is preferred unless overridden by confidence or conflict resolution logic.
        - secondary: The contrastive router used to provide a second opinion or trigger conflict resolution logic.
        - supportedDomains: A list of valid domains this router recognizes.
        - confidenceThreshold: An optional confidence threshold for favoring the more confident prediction between the two routers.
        - fallbackDomain: An optional fallback domain if both routers are uncertain.
        - fallbackConfidenceThreshold: An optional confidence threshold under which both predictions are considered uncertain.
        - allowSyntheticFallbacks: If true, fallback predictions will be synthesized instead of returning nil.
        - logger: A custom logger for logging domain predictions and conflicts.
        - conflictLogger: A logging strategy for capturing conflicts between primary and secondary predictions.
        - resolveConflict: A closure that resolves conflicts between the two predictions when confidence thresholds don’t resolve it.
     */
    public init(
        name: String,
        primary: LLMDomainRouterProtocol,
        secondary: LLMDomainRouterProtocol,
        supportedDomains: [String],
        confidenceThreshold: Double? = nil,
        fallbackDomain: String? = nil,
        fallbackConfidenceThreshold: Double? = nil,
        allowSyntheticFallbacks: Bool = false,
        logger: CustomLogger? = nil,
        conflictLogger: ConflictLoggingStrategy? = nil,
        resolveConflict: @escaping (_ primary: DualDomainPrediction?, _ secondary: DualDomainPrediction?) -> String?
    ) {
        self.name = name
        self.primary = primary
        self.secondary = secondary
        self.supportedDomains = supportedDomains.map { $0.lowercased() }
        self.confidenceThreshold = confidenceThreshold
        self.fallbackDomain = fallbackDomain?.lowercased()
        self.fallbackConfidenceThreshold = fallbackConfidenceThreshold
        self.allowSyntheticFallbacks = allowSyntheticFallbacks
        self.logger = logger
        self.conflictLogger = conflictLogger
        self.resolve = resolveConflict
    }

    /**
     Determines the domain for the given `LLMRequest` using the primary and secondary routers.

     - Parameters:
        - request: The request containing messages to be analyzed for routing.
     - Returns: A string representing the predicted domain if supported, or `nil` if not supported or below our confidence threshold.
     - Throws: Never throws currently, but declared for protocol conformance and future flexibility.
     */
    public func determineDomain(for request: LLMRequest) async throws -> String? {
        let primaryPrediction = try await prediction(from: primary, for: request)
        let secondaryPrediction = try await prediction(from: secondary, for: request)

        /// Check predictions for nil values and log accordingly.
        switch (primaryPrediction, secondaryPrediction) {
        case let (p?, s?):
            // Both predictions are valid — proceed with full conflict logic below
            logger?.debug("Both predictions available. Primary: '\(p.label)', Secondary: '\(s.label)'", category: "DualDomainRouter")
        case let (p?, nil):
            logger?.debug("Only primary prediction available. Using '\(p.label)'", category: "DualDomainRouter")
            return p.label
        case let (nil, s?):
            logger?.debug("Only secondary prediction available. Using '\(s.label)'", category: "DualDomainRouter")
            return s.label
        default:
            logger?.debug("Both predictions are nil. Returning fallback or nil.", category: "DualDomainRouter")
            return fallbackDomain
        }

        /// if both predictions are the same, return the prediction
        if primaryPrediction?.label == secondaryPrediction?.label {
            return primaryPrediction?.label
        }

        // Log the conflict details using the shared logger?.
        logger?.debug("""
        Conflict Detected:
        Prompt: \(request.messages.map(\.content).joined(separator: " "))
        Primary: \(primaryPrediction?.label ?? "nil") (\(primaryPrediction?.confidence ?? 0))
        Secondary: \(secondaryPrediction?.label ?? "nil") (\(secondaryPrediction?.confidence ?? 0))
        """, category: "DualDomainRouter")

        // Optionally, log conflicts to CSV via Conflictlogger?.
        conflictLogger?.logConflict(
            prompt: request.messages.map(\.content).joined(separator: " "),
            primary: primaryPrediction?.label ?? "nil",
            primaryConfidence: primaryPrediction?.confidence ?? 0,
            secondary: secondaryPrediction?.label ?? "nil",
            secondaryConfidence: secondaryPrediction?.confidence ?? 0
        )

        if shouldFallback(primaryPrediction, secondaryPrediction),
           let fallback = fallbackDomain {
            logger?.debug("Both predictions are below fallback threshold. Returning fallback domain '\(fallback)'.", category: "DualDomainRouter")
            return fallback
        }

        if confidenceExceedsThreshold(primaryPrediction, secondaryPrediction) {
            let winner = moreConfident(primaryPrediction, secondaryPrediction)
            logger?.debug("Confidence difference exceeds threshold. Using '\(winner?.label ?? "nil")'.", category: "DualDomainRouter")
            return winner?.label
        }

        // If we reach here, we need to resolve the conflict using the provided closure.
        logger?.debug("Confidence difference does not exceed threshold. Using custom resolution logic.", category: "DualDomainRouter")
        return resolve(primaryPrediction, secondaryPrediction)
    }

    // MARK: - Helper functions

    /**
        Retrieves the prediction and confidence from the specified router.

        - Parameters:
            - router: The router to retrieve the prediction from.
            - request: The request containing messages to be analyzed for routing.
        - Returns: A `DomainPrediction` containing the predicted domain and its confidence level.
        - Throws: An error if the prediction fails.

        This function is private and used internally to retrieve the prediction and confidence from the specified router. It handles both confident and non-confident routers. If the domain cannot be determined, the `fallbackDomain` is returned with a confidence of 0. If `fallbackDomain` is not set and `allowSyntheticFallbacks` is `true`, "unknown" is returned.
     */
    private func prediction(from router: LLMDomainRouterProtocol,
                            for request: LLMRequest
    ) async throws -> DualDomainPrediction? {
        if let c = router as? ConfidentDomainRouter,
           let (label, conf) = try await c.determineDomainWithConfidence(for: request) {
            return DualDomainPrediction(label: label.lowercased(), confidence: conf)
        } else if let label = try await router.determineDomain(for: request) {
            return DualDomainPrediction(label: label.lowercased(), confidence: 1.0)
        } else {
            guard allowSyntheticFallbacks else { return nil }
            return DualDomainPrediction(label: fallbackDomain ?? "unknown", confidence: 0)
        }
    }

    // MARK: - Threshold Logic

    /// Returns true if both predictions fall below the fallback threshold.
    private func shouldFallback(_ p1: DualDomainPrediction?, _ p2: DualDomainPrediction?) -> Bool {
        guard let threshold = fallbackConfidenceThreshold else { return false }
        return (p1?.confidence ?? 0) < threshold && (p2?.confidence ?? 0) < threshold
    }

    /// Returns true if the confidence delta between predictions meets or exceeds the threshold.
    private func confidenceExceedsThreshold(_ p1: DualDomainPrediction?, _ p2: DualDomainPrediction?) -> Bool {
        guard let t = confidenceThreshold,
              let p1 = p1,
              let p2 = p2 else { return false }
        return abs(p1.confidence - p2.confidence) >= t
    }

    /// Returns the prediction with higher confidence.
    private func moreConfident(_ p1: DualDomainPrediction?, _ p2: DualDomainPrediction?) -> DualDomainPrediction? {
        guard let p1 = p1, let p2 = p2 else { return p1 ?? p2 }
        return p1.confidence >= p2.confidence ? p1 : p2
    }
}

// MARK: - Conflict Logging

/**
    This protocol defines a method for logging conflicts between primary and secondary predictions.
 */
public protocol ConflictLoggingStrategy {
    /// Logs a conflict with the provided details.
    func logConflict(prompt: String, primary: String, primaryConfidence: Double, secondary: String, secondaryConfidence: Double)
}

/**
    A file-based conflict logger that appends conflict details to a CSV file.
 */
public final class FileConflictLogger: ConflictLoggingStrategy {

    private var fileHandle: FileHandle?
    private let dateFormatter: DateFormatter
    private let logger: CustomLogger?

    /**
        Public initializer that sets up CSV logging using a specified file name.

        - Parameters:
            - fileName: The base name for the log file.
            - directory: The directory where the log file will be created. Defaults to the app's document directory.

        - Note: The file will be created if it doesn't exist, and a CSV header will be added.
     */
    public init(fileName: String, directory: URL? = nil, logger: CustomLogger? = nil) {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        self.logger = logger

        let baseURL = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let logDirectory = baseURL else {
            logger?.error("Unable to resolve log directory", category: "FileConflictLogger")
            return
        }

        let sanitizedFileName = fileName.hasSuffix(".csv") ? fileName : "\(fileName).csv"
        let fileURL = logDirectory.appendingPathComponent(sanitizedFileName)

        do {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try "timestamp,prompt,primary,primaryConfidence,secondary,secondaryConfidence\n"
                    .write(to: fileURL, atomically: true, encoding: .utf8)
            }

            self.fileHandle = try FileHandle(forWritingTo: fileURL)
            self.fileHandle?.seekToEndOfFile()
            logger?.debug("CSV log file created at \(fileURL)", category: "FileConflictLogger")
        } catch {
            logger?.error("Failed to initialize file logger: \(error)", category: "FileConflictLogger")
        }
    }

    /**
     Logs a conflict with the provided details.

     - Parameters:
        - prompt: The user prompt that led to the conflict.
        - primary: The primary router's prediction.
        - primaryConfidence: The confidence level of the primary prediction.
        - secondary: The secondary router's prediction.
        - secondaryConfidence: The confidence level of the secondary prediction.
     */
    public func logConflict(
        prompt: String,
        primary: String,
        primaryConfidence: Double,
        secondary: String,
        secondaryConfidence: Double
    ) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "\(timestamp),\"\(prompt)\",\(primary),\(primaryConfidence),\(secondary),\(secondaryConfidence)\n"

        if let data = line.data(using: .utf8) {
            fileHandle?.write(data)
        }
    }

    deinit {
        fileHandle?.closeFile()
    }
}

/**
    A console-based conflict logger that prints conflict details to the console.
 */
public final class ConsoleConflictLogger: ConflictLoggingStrategy {
    private let logger: CustomLogger?

    /**
        Public initializer that sets up console logging.

        - Parameters:
            - logger: An optional custom logger for logging conflict details.
     */
    public init(logger: CustomLogger? = nil) {
        self.logger = logger
    }

    /**
     Logs a conflict with the provided details.

     - Parameters:
        - prompt: The user prompt that led to the conflict.
        - primary: The primary router's prediction.
        - primaryConfidence: The confidence level of the primary prediction.
        - secondary: The secondary router's prediction.
        - secondaryConfidence: The confidence level of the secondary prediction.
     */
    public func logConflict(
        prompt: String,
        primary: String,
        primaryConfidence: Double,
        secondary: String,
        secondaryConfidence: Double
    ) {
        logger?.debug("[\(Date())] Conflict: \(prompt) | Primary: \(primary) (\(primaryConfidence)) | Secondary: \(secondary) (\(secondaryConfidence))", category: "ConsoleConflictLogger")
    }
}
