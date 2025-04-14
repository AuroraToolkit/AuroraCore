//
//  CoreMLDomainRouter.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 4/14/25.
//

import Foundation
import CoreML
import NaturalLanguage
import AuroraCore

/// A domain router that uses a Core ML–based natural language classifier to predict the domain of a request.
/// 
/// The router loads a compiled `.mlmodelc` file into an `NLModel` and uses it to classify incoming request content.
/// If the predicted label is not found in the list of supported domains, the router returns "general" by default.
public class CoreMLDomainRouter: LLMDomainRouterProtocol {

    /// The name of the router, used for logging and identification.
    public let name: String

    /// The list of valid domains this router recognizes.
    public let supportedDomains: [String]

    /// The Core ML–powered natural language classification model.
    private let model: NLModel

    /// Shared logger instance.
    private let logger = CustomLogger.shared

    /**
     Initializes a Core ML–based domain router using a compiled Core ML model.
     
     - Parameters:
        - name: A human-readable identifier for this router.
        - modelURL: The file URL to the compiled `.mlmodelc` Core ML classifier.
        - supportedDomains: A list of supported domain strings. The model must return one of these values to be considered valid.
     
     - Returns: An instance of `CoreMLDomainRouter` or `nil` if model loading fails.
     */
    public init?(name: String, modelURL: URL, supportedDomains: [String]) {
        guard let nlModel = try? NLModel(contentsOf: modelURL) else {
            logger.error("Failed to load Core ML model at \(modelURL)", category: "CoreMLDomainRouter")
            return nil
        }

        self.name = name
        self.model = nlModel
        self.supportedDomains = supportedDomains.map { $0.lowercased() }
    }

    /**
     Determines the domain for the given `LLMRequest` using the Core ML text classifier.
     
     - Parameters:
        - request: The request containing messages to be analyzed for routing.

     - Returns: A string representing the predicted domain. Returns `"general"` if prediction fails or is unsupported.
     
     - Throws: Never throws currently, but declared for protocol conformance and future flexibility.
     */
    public func determineDomain(for request: LLMRequest) async throws -> String {
        // Flatten all message contents into a single prompt string
        let prompt = request.messages.map(\.content).joined(separator: " ")

        // Run prediction using the loaded NLModel
        guard let prediction = model.predictedLabel(for: prompt)?.lowercased() else {
            logger.debug("Model failed to predict. Defaulting to 'general'", category: "CoreMLDomainRouter")
            return "general"
        }

        // Return predicted domain if it's supported, otherwise fallback
        if supportedDomains.contains(prediction) {
            return prediction
        } else {
            logger.debug("Unsupported domain '\(prediction)' returned. Defaulting to 'general'", category: "CoreMLDomainRouter")
            return "general"
        }
    }
}
