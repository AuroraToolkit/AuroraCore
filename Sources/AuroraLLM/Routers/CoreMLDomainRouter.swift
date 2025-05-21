//
//  CoreMLDomainRouter.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 4/14/25.
//

import AuroraCore
import CoreML
import Foundation
import NaturalLanguage

/// A domain router that uses a Core ML–based natural language classifier to predict the domain of a request.
///
/// The router loads a compiled `.mlmodelc` file into an `NLModel` and uses it to classify incoming request content.
/// If the predicted label is not found in the list of supported domains, the router returns "general" by default.
public class CoreMLDomainRouter: ConfidentDomainRouter {
    /// The name of the router, used for logging and identification.
    public let name: String

    /// The list of valid domains this router recognizes.
    public let supportedDomains: [String]

    /// The Core ML–powered natural language classification model.
    private let model: NLModel

    /// Shared logger instance.
    private let logger: CustomLogger?

    /**
     Initializes a Core ML–based domain router using a compiled Core ML model.

     - Parameters:
        - name: A human-readable identifier for this router.
        - modelURL: The file URL to the compiled `.mlmodelc` Core ML classifier.
        - supportedDomains: A list of supported domain strings. The model must return one of these values to be considered valid.
        - logger: An optional logger instance for logging messages.

     - Returns: An instance of `CoreMLDomainRouter` or `nil` if model loading fails.
     */
    public init?(name: String, modelURL: URL, supportedDomains: [String], logger: CustomLogger? = nil) {
        guard let nlModel = try? NLModel(contentsOf: modelURL) else {
            logger?.error("Failed to load Core ML model at \(modelURL)", category: "CoreMLDomainRouter")
            return nil
        }

        self.name = name
        model = nlModel
        self.supportedDomains = supportedDomains.map { $0.lowercased() }
        self.logger = logger
    }

    /**
     Determines the domain for the given `LLMRequest` using the Core ML text classifier.

     - Parameters:
        - request: The request containing messages to be analyzed for routing.
     - Returns: A string representing the predicted domain. Returns `nil` if prediction fails or is unsupported.
     - Throws: Never throws currently, but declared for protocol conformance and future flexibility.

     For best results, consider normalizing the prompt text (e.g., removing emojis or punctuation) before calling this method.
     */
    public func determineDomain(for request: LLMRequest) async throws -> String? {
        // Flatten all message contents into a single prompt string
        let prompt = request.messages.map(\.content).joined(separator: " ")

        // Run prediction using the loaded NLModel
        guard let prediction = model.predictedLabel(for: prompt)?.lowercased() else {
            logger?.debug("Model failed to predict. Returning 'nil'", category: "CoreMLDomainRouter")
            return nil
        }

        if prediction.isEmpty {
            logger?.error("Model returned an empty string as prediction for prompt: \(prompt)", category: "CoreMLDomainRouter")
            return nil
        }

        // Return predicted domain if it's supported, otherwise `nil`
        if supportedDomains.contains(prediction) {
            return prediction
        } else {
            logger?.debug("Unsupported domain '\(prediction)' returned. Returning 'nil'", category: "CoreMLDomainRouter")
            return nil
        }
    }

    /**
        Determines the domain for the given `LLMRequest` and provides a confidence score.

        - Parameters:
            - request: The request containing messages to be analyzed for routing.
        - Returns: A tuple containing the predicted domain and its confidence score, or `nil` if prediction fails or is unsupported.
        - Throws: Never throws currently, but declared for protocol conformance and future flexibility.

        For best results, consider normalizing the prompt text (e.g., removing emojis or punctuation) before calling this method.
     */
    public func determineDomainWithConfidence(for request: LLMRequest) async throws -> (String, Double)? {
        let prompt = request.messages.map(\.content).joined(separator: " ")

        // Get top label hypotheses
        let hypotheses = model.predictedLabelHypotheses(for: prompt, maximumCount: 1)

        // Grab the most probable one
        guard let (label, confidence) = hypotheses.first else {
            logger?.debug("No predictions. Returning 'nil'", category: "CoreMLDomainRouter")
            return nil
        }

        let domain = label.lowercased()
        if supportedDomains.contains(domain) {
            return (domain, confidence)
        } else {
            logger?.debug("Unsupported domain '\(domain)' with confidence \(confidence). Returning 'nil'", category: "CoreMLDomainRouter")
            return nil
        }
    }
}
