//
//  LLMManager.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/19/24.
//

import Foundation
import os.log

/**
 `LLMManager` is responsible for managing multiple LLM services and routing requests to the appropriate service based on the specified criteria.
 It allows registering, unregistering, and selecting services based on routing options such as token limit or domain, as well as providing fallback service support.
 */
public class LLMManager {

    /// Routing options for selecting an appropriate LLM service.
    public enum Routing: CustomStringConvertible, Equatable {
        case tokenLimit
        case domain([String])

        /// A human-readable description of each routing strategy.
        public var description: String {
            switch self {
            case .tokenLimit:
                return "Token Limit"
            case .domain(let domains):
                return "Domain (\(domains.joined(separator: ", ")))"
            }
        }
    }

    /// A logger for recording information and errors within the `LLMManager`.
    private let logger = Logger(subsystem: "com.mutantsoup.AuroraCore", category: "LLMManager")

    /// A dictionary mapping service names to their respective `LLMServiceProtocol` instances with `Routing` options.
    private(set) var services: [String: (service: LLMServiceProtocol, routingOptions: [Routing])] = [:]

    /// The name of the currently active service.
    private(set) var activeServiceName: String?

    /// The designated fallback service.
    private(set) var fallbackService: LLMServiceProtocol?

    public init() {}

    // MARK: - Registering Services

    /**
     Registers a new LLM service or replaces an existing one with the same name.

     - Parameters:
     - service: The service conforming to `LLMServiceProtocol` to be registered.
     - withRouting: The `Routing` options, if any, for the service.

     If a service with the same name already exists, it is replaced. Sets the first registered service as the active service if no active service is set.
     */
    public func registerService(_ service: LLMServiceProtocol, withRouting routing: [Routing] = [.tokenLimit]) {
        let serviceName = service.name.lowercased()

        if services[serviceName] != nil {
            logger.log("Replacing existing service with name '\(serviceName)'")
        } else {
            logger.log("Registering new service with name '\(serviceName)'")
        }

        services[serviceName] = (service, routing)

        if activeServiceName == nil {
            activeServiceName = serviceName
            logger.log("Active service set to: \(self.activeServiceName ?? "nil")")
        }
    }

    /**
        Registers a new fallback LLM service or replaces an existing one.

        - Parameter service: The service conforming to `LLMServiceProtocol` to be registered as a fallback.
     */
    public func registerFallbackService(_ service: LLMServiceProtocol) {
        if fallbackService != nil {
            logger.log("Replacing existing fallback service with name '\(service.name)'")
        } else {
            logger.log("Registering new fallback service with name '\(service.name)'")
        }

        fallbackService = service
    }



    /**
     Unregisters an LLM service with a specified name.

     - Parameters:
     - name: The name under which the service is registered.

     If the service being unregistered is the active service, the active service is reset to the first available service or nil if no services are left.
     */
    public func unregisterService(withName name: String) {
        let serviceName = name.lowercased()
        logger.log("Unregistering service: \(serviceName)")

        services[serviceName] = nil

        if activeServiceName == serviceName {
            activeServiceName = services.keys.first
            logger.log("Active service set to: \(self.activeServiceName ?? "nil")")
        }
    }

    // MARK: - Set Active Service

    /**
     Sets the active LLM service by its registered name.

     - Parameter name: The name of the service to be set as active.

     Logs an error if the specified name does not correspond to a registered service.
     */
    public func setActiveService(byName name: String) {
        guard services[name.lowercased()] != nil else {
            logger.error("Attempted to set active service to unknown service: \(name)")
            return
        }
        activeServiceName = name
        logger.log("Active service switched to: \(self.activeServiceName ?? "nil")")
    }

    // MARK: - Send Request

    /**
     Sends a request to an LLM service, applying the specified routing and token trimming strategies if necessary.

     - Parameters:
     - request: The `LLMRequest` containing the messages and parameters.
     - routing: The routing option to select the appropriate service. Defaults to `.default`.
     - buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
     - trimming: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.
     - Returns: An optional `LLMResponseProtocol` object.

     This function trims the content if it exceeds the token limit of the selected service and sends the request.
     */
    public func sendRequest(
        _ request: LLMRequest,
        routing: Routing = .tokenLimit,
        buffer: Double = 0.05,
        trimming: String.TrimmingStrategy = .end
    ) async -> LLMResponseProtocol? {
        return await optimizeAndSendRequest(request, onPartialResponse: nil, routing: routing, buffer: buffer, trimming: trimming)
    }

    // MARK: - Streaming Request

    /**
     Sends a streaming request to an LLM service, applying the specified routing and token trimming strategies if necessary.

     - Parameters:
     - request: The `LLMRequest` containing the messages and parameters.
     - onPartialResponse: A closure that handles partial responses during streaming.
     - routing: The routing option to select the appropriate service. Defaults to `.default`.
     - buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
     - trimming: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.
     - Returns: An optional `LLMResponseProtocol` object.

     This function trims the content if it exceeds the token limit of the selected service and sends the streaming request.
     */
    public func sendStreamingRequest(
        _ request: LLMRequest,
        onPartialResponse: ((String) -> Void)?,
        routing: Routing = .tokenLimit,
        buffer: Double = 0.05,
        trimming: String.TrimmingStrategy = .end
    ) async -> LLMResponseProtocol? {
        // Enable streaming in the request
        let streamingRequest = LLMRequest(
            messages: request.messages,
            temperature: request.temperature,
            maxTokens: request.maxTokens,
            model: request.model,
            stream: true,   // Ensure streaming is enabled
            options: request.options
        )
        return await optimizeAndSendRequest(streamingRequest, onPartialResponse: onPartialResponse, routing: routing, buffer: buffer, trimming: trimming)
    }

    // MARK: - Helper Methods

    /**
     Sends a streaming request to an LLM service, applying the specified routing and token trimming strategies if necessary.

     - Parameters:
     - request: The `LLMRequest` containing the messages and parameters.
     - onPartialResponse: A closure that handles partial responses during streaming.
     - routing: The routing option to select the appropriate service. Defaults to `.default`.
     - buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
     - trimming: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.
     - Returns: An optional `LLMResponseProtocol` object.

     This function trims the content if it exceeds the token limit of the selected service and sends the streaming request.
     */
    private func optimizeAndSendRequest(
        _ request: LLMRequest,
        onPartialResponse: ((String) -> Void)?,
        routing: Routing = .tokenLimit,
        buffer: Double = 0.05,
        trimming: String.TrimmingStrategy = .end
    ) async -> LLMResponseProtocol? {
        let optimizedRequest = optimizeRequest(request, trimming: trimming, buffer: buffer)

        // Select the appropriate service based on the optimized request
        let selectedService = selectService(basedOn: routing, for: optimizedRequest)

        guard let service = selectedService else {
            logger.error("No service available for the specified routing strategy.")
            return nil
        }

        logger.log("Sending request to service: \(service.name), model: \(optimizedRequest.model ?? "Not specified")")

        return await sendRequestToService(service, withRequest: optimizedRequest, onPartialResponse: onPartialResponse)
    }

    /**
        Optimizes the request by trimming the content to fit within the token limit of the selected service.

        - Parameters:
            - request: The `LLMRequest` to optimize.
            - trimming: The trimming strategy to apply when tokens exceed the limit.
            - buffer: The buffer percentage to apply to the token limit.
        - Returns: An optimized `LLMRequest` object.
     */
    private func optimizeRequest(_ request: LLMRequest, trimming: String.TrimmingStrategy, buffer: Double) -> LLMRequest {
        // If trimming is set to .none, skip trimming and use the original request
        let optimizedRequest: LLMRequest
        if trimming == .none {
            optimizedRequest = request
        } else {
            // Determine the maximum token limit across all registered services
            let maxTokenLimit = services.values.map { $0.service.maxTokenLimit }.max() ?? Int.max

            // Trim messages to fit within the maximum token limit across all services
            let trimmedMessages = trimMessages(request.messages, toFitTokenLimit: maxTokenLimit, buffer: buffer, strategy: trimming)
            optimizedRequest = LLMRequest(
                messages: trimmedMessages,
                temperature: request.temperature,
                maxTokens: request.maxTokens,
                model: request.model,
                stream: request.stream,
                options: request.options
            )
        }
        return optimizedRequest
    }

    /**
     Trims the content of the provided messages to fit within a token limit, applying a buffer and trimming strategy.

     - Parameters:
         - messages: The array of `LLMMessage` objects to trim.
         - limit: The maximum token limit allowed for the message content.
         - buffer: The buffer percentage to apply to the token limit.
         - strategy: The trimming strategy to use if content exceeds the token limit.
     - Returns: An array of trimmed `LLMMessage` objects fitting within the token limit.
     */
    private func trimMessages(_ messages: [LLMMessage], toFitTokenLimit limit: Int, buffer: Double, strategy: String.TrimmingStrategy) -> [LLMMessage] {
        let trimmedContent = messages
            .map { $0.content }
            .joined(separator: " ")
            .trimmedToFit(tokenLimit: limit, buffer: buffer, strategy: strategy)

        return [LLMMessage(role: .user, content: trimmedContent)]
    }

    /**
     Sends a request to a specific LLM service.

     - Parameters:
        - service: The `LLMServiceProtocol` conforming service.
        - request: The `LLMRequest` to send.
        - onPartialResponse: A closure that handles partial responses during streaming (optional).
        - isRetryingWithFallback: A flag indicating whether the request is a retry with a fallback service.
     - Returns: An optional `LLMResponseProtocol` object.
     */
    private func sendRequestToService(
        _ service: LLMServiceProtocol,
        withRequest request: LLMRequest,
        onPartialResponse: ((String) -> Void)? = nil,
        isRetryingWithFallback: Bool = false
    ) async -> LLMResponseProtocol? {
        do {
            // Attempt sending request with the active or selected service
            if let onPartialResponse = onPartialResponse {
                let response = try await service.sendStreamingRequest(request, onPartialResponse: onPartialResponse)
                logger.log("Service succeeded with streaming response.")
                return response
            } else {
                let response = try await service.sendRequest(request)
                logger.log("Service succeeded with response.")
                return response
            }
        } catch {
            // Log the failure
            logger.error("Service \(service.name) failed with error: \(error.localizedDescription)")

            // Attempt to retry with a fallback service if available
            if let fallbackService, !isRetryingWithFallback {
                logger.log("Retrying request with fallback service: \(fallbackService.name)")
                return await sendRequestToService(fallbackService, withRequest: request, onPartialResponse: onPartialResponse, isRetryingWithFallback: true)
            }

            // If no fallback service is available or both fail, return nil
            logger.error("No fallback service succeeded or available after failure of \(service.name).")
            return nil
        }
    }

    /**
     Chooses an LLM service based on the provided routing strategy.

     - Parameters:
         - routing: The routing strategy to be applied for selection.
         - request: The request being sent, used for analyzing compatibility.
     - Returns: The `LLMServiceProtocol` that matches the given routing strategy, if available.
     */
    private func selectService(basedOn routing: Routing, for request: LLMRequest) -> LLMServiceProtocol? {
        // Sort services by name to ensure deterministic ordering
        let sortedServices = services.values.sorted { $0.service.name < $1.service.name }

        // Try the active service if it meets the criteria
        if let activeServiceName = activeServiceName,
           let activeService = services[activeServiceName]?.service,
           serviceMeetsCriteria(activeService, routing: routing, for: request) {
            logger.log("Routing to active service: \(activeService.name)")
            return activeService
        }

        // Try any other matching service
        if let matchingService = sortedServices.first(where: {
            serviceMeetsCriteria($0.service, routing: routing, for: request)
        })?.service {
            logger.log("Routing to service matching strategy \(routing): \(matchingService.name)")
            return matchingService
        }

        // Attempt fallback routing if available
        if let fallbackService {
            logger.log("Routing to fallback service: \(fallbackService.name)")
            return fallbackService
        }

        // No suitable service found
        logger.log("No suitable service found for routing strategy \(routing), and no fallback available.")
        return nil
    }

    /**
     Evaluates whether a given `LLMServiceProtocol` service meets the criteria specified by a routing strategy for the given request.

     - Parameters:
        - service: The service being evaluated.
        - routing: The routing strategy that specifies which criteria to evaluate, defaults to `.tokenLimit`.
        - request: The `LLMRequest` providing details such as token count and preferred domains.

     - Returns: `true` if the service meets the criteria specified by the routing strategy; `false` otherwise.

     - Routing criteria:
        - **TokenLimit**: Confirms that the service's token capacity can handle the estimated token count in the request.
        - **Domain**: Ensures the service covers the preferred domains specified in the request.
     */
    private func serviceMeetsCriteria(_ service: LLMServiceProtocol, routing: Routing, for request: LLMRequest) -> Bool {
        let apiKeyRequirementMet = !service.requiresAPIKey || service.apiKey != nil

        logger.log("Evaluating service \(service.name) for routing strategy \(routing)")
        logger.log("Request details:\n - Estimated token count: \(request.estimatedTokenCount())\n - Max tokens: \(request.maxTokens)")

        switch routing {
        case .tokenLimit:
            // Token limit routing checks if the service can handle the token count in the request
            let requestTokenCount = request.estimatedTokenCount()
            let tokenLimitRequirementMet = service.maxTokenLimit >= requestTokenCount
            logger.log(".tokenLimit APIKey requirement met: \(apiKeyRequirementMet) Token limit requirement met: \(tokenLimitRequirementMet)")
            return apiKeyRequirementMet && tokenLimitRequirementMet

        case .domain(let preferredDomains):
            // Domain routing checks if the service covers the preferred domains
            let lowercasePreferredDomains = Set(preferredDomains.map { $0.lowercased() })
            let serviceDomains = services[service.name.lowercased()]?.routingOptions.compactMap { option in
                if case let .domain(domains) = option { return domains.map { $0.lowercased() } }
                return nil
            }.flatMap { $0 } ?? []
            let serviceDomainsRequirementMet = lowercasePreferredDomains.isSubset(of: Set(serviceDomains))

            logger.log(".domain() APIKey requirement met: \(apiKeyRequirementMet) Preferred domains: \(lowercasePreferredDomains) Service domains met: \(serviceDomainsRequirementMet)")
            return apiKeyRequirementMet && serviceDomainsRequirementMet
        }
    }
}
