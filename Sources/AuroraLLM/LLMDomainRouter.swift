//
//  LLMDomainRouter.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/11/24.
//


import Foundation
import os.log
import AuroraCore

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


/**
    The `LLMDomainRouter` class is responsible for determining the domain of a request using an LLM service.

    The router uses the service to process the request and identify the domain. If the domain is not in the list of supported domains, a fallback ("unresolved") is returned.

    - Note: The router is initialized with a list of supported domains and a system prompt that guides the LLM in determining the domain. The LLM is instructed to return "unresolved" if the domain is not supported, which will return "unresolved" if included in the supported domains, or `nil` if not.
 */
public class LLMDomainRouter: LLMDomainRouterProtocol {

    public let name: String
    public var service: LLMServiceProtocol
    public let supportedDomains: [String]
    private let logger = CustomLogger.shared
    private let DEFAULT_INSTRUCTIONS = """
Evaluate the following request and determine the domain it belongs to. Domains we support are: %@.

If it doesn't fit any of these domains, just use unresolved as the domain. You should respond to any question with ONLY 
the domain name if we support it, or unresolved if we don't. Do NOT try to answer the question or provide ANY additional 
information.
"""

    /**
     Initializes the domain router with an LLM service and a list of supported domains.

     - Parameters:
        - name: The name of the domain router.
        - service: The `LLMServiceProtocol` used to determine the domain.
        - supportedDomains: A list of domains that the router supports.
        - instructions: Instructions to include in the system prompt. If not provided, a default set of instructions is used.

     - Note: The instructions *must* include a `%@` placeholder for the list of supported domains.
     */
    public init(name: String, service: LLMServiceProtocol, supportedDomains: [String], instructions: String? = nil) {
        self.name = name
        self.service = service
        self.supportedDomains = supportedDomains.map { $0.lowercased() }
        configureSystemPrompt(instructions ?? DEFAULT_INSTRUCTIONS)
    }

    /**
        Configures the system prompt for the domain router.

        - Parameters:
            - instructions: Instructions to include in the system prompt.

        The system prompt is used to guide the user in determining the domain for a given input.
     */
    private func configureSystemPrompt(_ instructions: String) {
        let domainList = supportedDomains.joined(separator: ", ")
        service.systemPrompt = String(format: instructions, domainList)
    }

    /**
     Determines the domain for a given request using the associated LLM service.

     - Parameters:
        - request: The `LLMRequest` containing the prompt or context for domain determination.

     - Returns: A string representing the determined domain.
     
     - Throws: An error if the service fails to process the request.

     - Discussion:
        The method uses the associated `LLMServiceProtocol` to process the request and identify the domain.
        If the domain is not in the list of supported domains, a fallback ("general") is returned.
     */
    public func determineDomain(for request: LLMRequest) async throws -> String? {
        // Prepend the system prompt if defined for the service
        var routedRequest = request
        if let systemPrompt = service.systemPrompt {
            var messages = request.messages
            messages.insert(LLMMessage(role: .system, content: systemPrompt), at: 0)
            routedRequest = LLMRequest(
                messages: messages,
                temperature: request.temperature,
                maxTokens: request.maxTokens,
                model: request.model,
                stream: request.stream,
                options: request.options
            )
        }

        do {
            // Send the request to the LLM service
            let response = try await service.sendRequest(routedRequest)
            let domain = response.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            logger.debug("Domain resolved by service: \(domain)", category: "LLMDomainRouter")

            // Validate the domain against supported domains
            if supportedDomains.contains(domain) {
                return domain
            } else {
                logger.debug("Domain '\(domain)' not in supported domains. Returning 'nil'.", category: "LLMDomainRouter")
                return nil
            }
        } catch {
            logger.error("Failed to determine domain: \(error.localizedDescription)", category: "LLMDomainRouter")
            throw error
        }
    }
}
