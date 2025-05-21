//
//  LLMDomainRouterProtocol.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/11/24.
//

import Foundation

/// Protocol defining the behavior of a domain router in the LLMManager system.
public protocol LLMDomainRouterProtocol {
    /// The name of the domain router, used for logging and identification purposes.
    var name: String { get }

    /// A list of domains that the router supports.
    var supportedDomains: [String] { get }

    /**
        Determines the domain for a given request using the associated LLM service.

        - Parameters:
            - request: The `LLMRequest` containing the prompt or context for domain determination.

        - Returns: A string representing the determined domain, or `nil` if not posslbe.
     */
    func determineDomain(for request: LLMRequest) async throws -> String?
}

/**
    Protocol defining the behavior of a domain router that can provide confidence scores for domain determination.

    - Note: This protocol extends `LLMDomainRouterProtocol` to include a method for determining the domain with a confidence score.
 */
public protocol ConfidentDomainRouter: LLMDomainRouterProtocol {
    /**
        Determines the domain for a given request using the associated LLM service.

        - Parameters:
            - request: The `LLMRequest` containing the prompt or context for domain determination.

        - Returns: A string representing the determined domain, and double representing confidence, or `nil` if not possible.
     */
    func determineDomainWithConfidence(for request: LLMRequest) async throws -> (String, Double)?
}
