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
        case inputTokenLimit(Int)
        case domain([String])

        /// A human-readable description of each routing strategy.
        public var description: String {
            switch self {
            case .inputTokenLimit(let limit):
                return "Input Token Limit (\(limit))"
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

     - Parameter service: The service conforming to `LLMServiceProtocol` to be registered.
     - Parameter withRouting: The `Routing` options, if any, for the service. Defaults to `[.inputTokenLimit(256)]`.

     If a service with the same name already exists, it is replaced. Sets the first registered service as the active service if no active service is set.
     */
    public func registerService(_ service: LLMServiceProtocol, withRouting routing: [Routing] = [.inputTokenLimit(256)]) {
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

     - Parameter name: The name under which the service is registered.

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

     - Parameter request: The `LLMRequest` containing the messages and parameters.
     - Parameter routing: The routing option to select the appropriate service. Defaults to `.inputTokenLimit(256)`.
     - Parameter buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
     - Parameter trimming: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.
     - Returns: An optional `LLMResponseProtocol` object.

     This function trims the content if it exceeds the token limit of the selected service and sends the request.
     */
    public func sendRequest(
        _ request: LLMRequest,
        routing: Routing = .inputTokenLimit(256),
        buffer: Double = 0.05,
        trimming: String.TrimmingStrategy = .end
    ) async -> LLMResponseProtocol? {
        return await optimizeAndSendRequest(request, onPartialResponse: nil, routing: routing, buffer: buffer, trimming: trimming)
    }

    // MARK: - Streaming Request

    /**
     Sends a streaming request to an LLM service, applying the specified routing and token trimming strategies if necessary.

     - Parameter request: The `LLMRequest` containing the messages and parameters.
     - Parameter onPartialResponse: A closure that handles partial responses during streaming.
     - Parameter routing: The routing option to select the appropriate service. Defaults to `.inputTokenLimit(256)`.
     - Parameter buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
     - Parameter trimming: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.
     - Returns: An optional `LLMResponseProtocol` object.

     This function trims the content if it exceeds the token limit of the selected service and sends the streaming request.
     */
    public func sendStreamingRequest(
        _ request: LLMRequest,
        onPartialResponse: ((String) -> Void)?,
        routing: Routing = .inputTokenLimit(256),
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

     - Parameter request: The `LLMRequest` containing the messages and parameters.
     - Parameter onPartialResponse: A closure that handles partial responses during streaming.
     - Parameter routing: The routing option to select the appropriate service. Defaults to `.inputTokenLimit(256)`.
     - Parameter buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
     - Parameter trimming: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.
     - Returns: An optional `LLMResponseProtocol` object.

     This function trims the content if it exceeds the token limit of the selected service and sends the streaming request.
     */
    private func optimizeAndSendRequest(
        _ request: LLMRequest,
        onPartialResponse: ((String) -> Void)?,
        routing: Routing = .inputTokenLimit(256),
        buffer: Double = 0.05,
        trimming: String.TrimmingStrategy = .end
    ) async -> LLMResponseProtocol? {
        logger.log("Selecting service based on request...")

        guard let selectedService = selectService(basedOn: routing, for: request, trimming: trimming) else {
            logger.error("No service available for the specified routing strategy.")
            return nil
        }

        logger.log("Sending request to service: \(selectedService.name), model: \(request.model ?? "Not specified")").self

        // Optimize request for the selected service
        logger.log("Optimizing request for service...")
        let optimizedRequest = optimizeRequest(request, for: selectedService, trimming: trimming, buffer: buffer)

        return await sendRequestToService(selectedService, withRequest: optimizedRequest, onPartialResponse: onPartialResponse)
    }

    /**
     Optimizes the `LLMRequest` to fit within the constraints of the selected service.

     - Parameter request: The `LLMRequest` to optimize.
     - Parameter service: The `LLMServiceProtocol` instance representing the selected service.
     - Parameter trimming: The trimming strategy to apply when tokens exceed the limit.
     - Parameter buffer: The buffer percentage to apply to the token limit, reducing the effective token limit slightly to allow for safer usage. Defaults to `0.05` (5%).

     - Returns: An optimized `LLMRequest` object, adjusted to ensure input and output tokens fit within the service's constraints.

     - Discussion:
     The optimization process considers the following:
     - The `contextWindowSize` represents the total allowable tokens (input + output tokens).
     - The `maxOutputTokens` represents the service's specific token limit for generating a response.
     - Input tokens are trimmed to fit within the context window after reserving space for output tokens.
     - If the `.none` trimming strategy is specified, the original request is returned unchanged.
     */
    private func optimizeRequest(
        _ request: LLMRequest,
        for service: LLMServiceProtocol,
        trimming: String.TrimmingStrategy,
        buffer: Double = 0.05
    ) -> LLMRequest {
        logger.log("Optimizing request for service \(service.name) with trimming strategy: \(trimming)")

        // Adjust service-specific constraints with the buffer applied
        let adjustedContextWindow = Int(Double(service.contextWindowSize) * (1 - buffer))
        var adjustedMaxOutputTokens = Int(Double(service.maxOutputTokens) * (1 - buffer))

        // Apply output token policy
        switch service.outputTokenPolicy {
        case .adjustToServiceLimits:
            adjustedMaxOutputTokens = min(request.maxTokens, adjustedMaxOutputTokens)
        case .strictRequestLimits:
            guard request.maxTokens <= adjustedMaxOutputTokens else {
                logger.log("Strict output token limit enforced: \(request.maxTokens) exceeds \(adjustedMaxOutputTokens).")
                return request
            }
        }

        let maxInputTokens = adjustedContextWindow - adjustedMaxOutputTokens


        // Insert the system prompt if it exists
        var allMessages = request.messages
        if let systemPrompt = service.systemPrompt {
            allMessages.insert(LLMMessage(role: .system, content: systemPrompt), at: 0)
        }

        // Trim input messages based on policy
        let trimmedMessages: [LLMMessage]
        switch service.inputTokenPolicy {
        case .adjustToServiceLimits:
            trimmedMessages = trimMessages(
                request.messages,
                toFitTokenLimit: maxInputTokens,
                buffer: buffer,
                strategy: trimming
            )
        case .strictRequestLimits:
            guard request.estimatedTokenCount() <= maxInputTokens else {
                logger.log("Strict input token limit enforced: \(request.estimatedTokenCount()) exceeds \(maxInputTokens).")
                return request
            }
            trimmedMessages = request.messages
        }

        return LLMRequest(
            messages: trimmedMessages,
            temperature: request.temperature,
            maxTokens: adjustedMaxOutputTokens,
            model: request.model,
            stream: request.stream,
            options: request.options
        )
    }

    /**
     Trims the content of the provided messages to fit within a token limit, applying a buffer and trimming strategy.

     - Parameter messages: The array of `LLMMessage` objects to trim.
     - Parameter limit: The maximum token limit allowed for the message content.
     - Parameter buffer: The buffer percentage to apply to the token limit.
     - Parameter strategy: The trimming strategy to use if content exceeds the token limit.
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

     - Parameter service: The `LLMServiceProtocol` conforming service.
     - Parameter request: The `LLMRequest` to send.
     - Parameter onPartialResponse: A closure that handles partial responses during streaming (optional).
     - Parameter isRetryingWithFallback: A flag indicating whether the request is a retry with a fallback service.
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

     - Parameter routing: The routing strategy to be applied for selection.
     - Parameter request: The request being sent, used for analyzing compatibility.
     - Returns: The `LLMServiceProtocol` that matches the given routing strategy, if available.
     */
    private func selectService(
        basedOn routing: Routing,
        for request: LLMRequest,
        trimming: String.TrimmingStrategy = .none
    ) -> LLMServiceProtocol? {
        // Sort services by routing specificity (e.g., tighter input token limits first)
        let sortedServices = services.values.sorted { lhs, rhs in
            switch routing {
            case .inputTokenLimit(_):
                let lhsLimit = lhs.routingOptions
                    .compactMap { if case let .inputTokenLimit(val) = $0 { return val } else { return nil } }
                    .first ?? Int.max
                let rhsLimit = rhs.routingOptions
                    .compactMap { if case let .inputTokenLimit(val) = $0 { return val } else { return nil } }
                    .first ?? Int.max
                return lhsLimit < rhsLimit // Prefer tighter token limits
            case .domain:
                return lhs.service.name < rhs.service.name // Default alphabetical sort for domain routing
            }
        }
        
        logger.log("Selecting service based on routing strategy: \(routing)")

        logger.log("Active service: \(self.activeServiceName ?? "nil"), Fallback service: \(self.fallbackService?.name ?? "nil")")

        // Try the active service if it meets the criteria
        if let activeServiceName = activeServiceName,
           let activeService = services[activeServiceName]?.service,
           serviceMeetsCriteria(activeService, routing: routing, for: request, trimming: trimming) {
            logger.log("Routing to active service: \(activeService.name)")
            return activeService
        }

        // Try any other matching service, excluding the active service
        if let matchingService = sortedServices.first(where: {
            $0.service.name.lowercased() != activeServiceName?.lowercased() &&
            serviceMeetsCriteria($0.service, routing: routing, for: request, trimming: trimming)
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

     - Parameter service: The service being evaluated.
     - Parameter routing: The routing strategy that specifies which criteria to evaluate.
     - Parameter request: The `LLMRequest` providing details such as token count and maximum output tokens.

     - Returns: `true` if the service meets the criteria specified by the routing strategy; `false` otherwise.

     - Routing Criteria:
     - **InputTokenLimit**: Ensures that the input tokens in the request fit within the effective input token limit of the service.
     - **Domain**: Ensures that the service supports the specified domain(s).

     - Discussion:
     - `contextWindowSize` defines the total token budget for both input and output tokens.
     - `maxOutputTokens` defines the maximum allowable tokens for generating a response.
     - The function validates that the service's `contextWindowSize` can accommodate the sum of input and output tokens in the request and ensures `maxOutputTokens` is not exceeded.
     */
    private func serviceMeetsCriteria(
        _ service: LLMServiceProtocol,
        routing: Routing,
        for request: LLMRequest,
        trimming: String.TrimmingStrategy = .none
    ) -> Bool {
        let apiKeyRequirementMet = !service.requiresAPIKey || service.apiKey != nil

        logger.log("Evaluating service \(service.name) for routing strategy \(routing) with trimming strategy \(trimming)")
        logger.log("Request details:\n - Estimated input tokens: \(request.estimatedTokenCount())\n - Max output tokens: \(request.maxTokens)")

        switch routing {
        case .inputTokenLimit(let limit):
            let originalInputTokens = request.estimatedTokenCount()
            var adjustedOutputTokens = request.maxTokens

            // Apply output token policy
            switch service.outputTokenPolicy {
            case .adjustToServiceLimits:
                if adjustedOutputTokens > service.maxOutputTokens {
                    logger.log("Warning: Adjusting output tokens to match service's limit (\(service.maxOutputTokens)).")
                    adjustedOutputTokens = service.maxOutputTokens
                }
            case .strictRequestLimits:
                if adjustedOutputTokens > service.maxOutputTokens {
                    logger.log("Strict limit enforced: Requested output tokens exceed service's limit.")
                    return false
                }
            }

            let totalOriginalTokens = originalInputTokens + adjustedOutputTokens

            // Effective input token limit
            let effectiveInputTokenLimit = min(limit, service.contextWindowSize - service.maxOutputTokens)

            // Apply input token policy
            let inputTokenRequirementMet: Bool
            switch service.inputTokenPolicy {
            case .adjustToServiceLimits:
                inputTokenRequirementMet = true // Trimming will handle adjustments
            case .strictRequestLimits:
                inputTokenRequirementMet = originalInputTokens <= effectiveInputTokenLimit
            }

            let outputTokenRequirementMet = adjustedOutputTokens <= service.maxOutputTokens
            let contextWindowRequirementMet = totalOriginalTokens <= service.contextWindowSize

            logger.log("Service \(service.name) - Effective input token limit: \(effectiveInputTokenLimit), Effective output token limit: \(service.maxOutputTokens), Context window: \(service.contextWindowSize)")
            logger.log("Input tokens: \(originalInputTokens), Adjusted output tokens: \(adjustedOutputTokens), Total tokens required: \(totalOriginalTokens)")
            logger.log("Input token requirement met: \(inputTokenRequirementMet), Output token requirement met: \(outputTokenRequirementMet), Context window requirement met: \(contextWindowRequirementMet)")

            return apiKeyRequirementMet && inputTokenRequirementMet && outputTokenRequirementMet && contextWindowRequirementMet

        case .domain(let preferredDomains):
            // Check domain support (unchanged)
            let lowercasePreferredDomains = Set(preferredDomains.map { $0.lowercased() })
            let serviceDomains = services[service.name.lowercased()]?.routingOptions.compactMap { option in
                if case let .domain(domains) = option { return domains.map { $0.lowercased() } }
                return nil
            }.flatMap { $0 } ?? []
            let serviceDomainsRequirementMet = lowercasePreferredDomains.isSubset(of: Set(serviceDomains))

            logger.log("Service \(service.name) - APIKey requirement met: \(apiKeyRequirementMet), Preferred domains: \(lowercasePreferredDomains), Service domains met: \(serviceDomainsRequirementMet)")

            return apiKeyRequirementMet && serviceDomainsRequirementMet
        }
    }
}
