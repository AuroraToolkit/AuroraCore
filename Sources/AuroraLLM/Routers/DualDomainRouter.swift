//
//  DualDomainRouter.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 4/15/25.
//

import Foundation
import AuroraCore

/// A domain router that combines two classifiers: a primary and a contrastive second opinion.
/// It compares results and optionally resolves conflicts using a strategy.
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
    public let fallbackConfidenceThreshold: Double?

    /// The primary and secondary domain routers.
    private let primary: LLMDomainRouterProtocol
    private let secondary: LLMDomainRouterProtocol

    /// A closure that resolves conflicts between the primary and secondary predictions.
    private let resolve: (_ primary: String, _ secondary: String) -> String

    /// Shared logger instance.
    private let logger = CustomLogger.shared

    /**
        Initializes a new `DualDomainRouter`.

        - Parameters:
            - name: The name of the router.
            - primary: The primary domain router.
            - secondary: The secondary domain router.
            - supportedDomains: A list of valid domains this router recognizes.
            - confidenceThreshold: An optional confidence threshold for predictions.
            - fallbackDomain: An optional fallback domain if both routers are uncertain.
            - fallbackConfidenceThreshold: An optional confidence threshold for the fallback domain.
            - resolveConflict: A closure that resolves conflicts between the primary and secondary predictions.

     - Returns: A new `DualDomainRouter` instance.
     */
    public init(
        name: String,
        primary: LLMDomainRouterProtocol,
        secondary: LLMDomainRouterProtocol,
        supportedDomains: [String],
        confidenceThreshold: Double? = nil,
        fallbackDomain: String? = nil,
        fallbackConfidenceThreshold: Double? = nil,
        resolveConflict: @escaping (_ primary: String, _ secondary: String) -> String
    ) {
        self.name = name
        self.primary = primary
        self.secondary = secondary
        self.supportedDomains = supportedDomains
        self.confidenceThreshold = confidenceThreshold
        self.fallbackDomain = fallbackDomain
        self.fallbackConfidenceThreshold = fallbackConfidenceThreshold
        self.resolve = resolveConflict
    }

    /**
     Determines the domain for the given `LLMRequest` using the primary and secondary routers.

     - Parameters:
        - request: The request containing messages to be analyzed for routing.

     - Returns: A string representing the predicted domain.

     - Throws: Never throws currently, but declared for protocol conformance and future flexibility.
     */
    public func determineDomain(for request: LLMRequest) async throws -> String {
        let (primaryPrediction, primaryConfidence): (String, Double)
        let (secondaryPrediction, secondaryConfidence): (String, Double)

        if let primaryConfident = primary as? ConfidentDomainRouter {
            (primaryPrediction, primaryConfidence) = try await primaryConfident.determineDomainWithConfidence(for: request)
        } else {
            primaryPrediction = try await primary.determineDomain(for: request)
            primaryConfidence = 1.0
        }

        if let secondaryConfident = secondary as? ConfidentDomainRouter {
            (secondaryPrediction, secondaryConfidence) = try await secondaryConfident.determineDomainWithConfidence(for: request)
        } else {
            secondaryPrediction = try await secondary.determineDomain(for: request)
            secondaryConfidence = 1.0
        }

        if primaryPrediction == secondaryPrediction {
            return primaryPrediction
        }

        logger.debug("🧠 Conflict: primary=\(primaryPrediction) (\(primaryConfidence)), secondary=\(secondaryPrediction) (\(secondaryConfidence))", category: "DualDomainRouter")

        // Check if both classifiers are uncertain and fallback is provided
        if let fallbackThreshold = fallbackConfidenceThreshold,
           let fallback = fallbackDomain,
           primaryConfidence < fallbackThreshold,
           secondaryConfidence < fallbackThreshold {
            logger.debug("🔸 Both classifiers are uncertain (primary: \(primaryConfidence), secondary: \(secondaryConfidence)). Falling back to '\(fallback)'.", category: "DualDomainRouter")
            return fallback
        }

        // Check if the confidence difference exceeds the threshold
        if let threshold = confidenceThreshold {
            let delta = abs(primaryConfidence - secondaryConfidence)
            if delta >= threshold {
                return primaryConfidence > secondaryConfidence ? primaryPrediction : secondaryPrediction
            }
        }

        // Fallback to manual resolution logic
        return resolve(primaryPrediction, secondaryPrediction)
    }
}
