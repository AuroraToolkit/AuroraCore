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
    private let logger = CustomLogger.shared

    /// A dictionary mapping service names to their respective `LLMServiceProtocol` instances with `Routing` options.
    private(set) var services: [String: (service: LLMServiceProtocol, routings: [Routing])] = [:]

    /// The name of the currently active service.
    private(set) var activeServiceName: String?

    /// The designated fallback service.
    private(set) var fallbackService: LLMServiceProtocol?

    /// The domain routing service used to determine the appropriate domain for a request.
    private(set) var domainRouter: LLMDomainRouterProtocol?

    public init() {}

    // MARK: - Registering Services

    /**
     Registers a new domain routing service or replaces an existing one.

     - Parameter router: The domain router conforming to `LLMDomainRouterProtocol` to be registered for domain routing.
     */
    public func registerDomainRouter(_ router: LLMDomainRouterProtocol) {
        if domainRouter != nil {
            logger.debug("Replacing existing domain router with '\(router.name)'", category: "LLMManager")
        } else {
            logger.debug("Registering new domain router with '\(router.name)'", category: "LLMManager")
        }
        domainRouter = router
    }

    /**
     Registers a new fallback LLM service or replaces an existing one.

     - Parameter service: The service conforming to `LLMServiceProtocol` to be registered as a fallback.
     */
    public func registerFallbackService(_ service: LLMServiceProtocol) {
        if fallbackService != nil {
            logger.debug("Replacing existing fallback service with name '\(service.name)'", category: "LLMManager")
        } else {
            logger.debug("Registering new fallback service with name '\(service.name)'", category: "LLMManager")
        }

        fallbackService = service
    }

    /**
     Registers a new LLM service or replaces an existing one with the same name.

     - Parameters:
        -  service: The service conforming to `LLMServiceProtocol` to be registered.
        -  withRoutings routing: The `Routing` options, if any, for the service. Defaults to `[.inputTokenLimit(256)]`.

     If a service with the same name already exists, it is replaced. Sets the first registered service as the active service if no active service is set.
     */
    public func registerService(_ service: LLMServiceProtocol, withRoutings routing: [Routing] = [.inputTokenLimit(256)]) {
        let serviceName = service.name.lowercased()

        if services[serviceName] != nil {
            logger.debug("Replacing existing service with name '\(serviceName)'", category: "LLMManager")
        } else {
            logger.debug("Registering new service with name '\(serviceName)'", category: "LLMManager")
        }

        services[serviceName] = (service, routing)

        if activeServiceName == nil {
            activeServiceName = serviceName
            logger.debug("Active service set to: \(self.activeServiceName ?? "nil")", category: "LLMManager")
        }
    }

    /**
     Unregisters an LLM service with a specified name.

     - Parameter name: The name under which the service is registered.

     If the service being unregistered is the active service, the active service is reset to the first available service or nil if no services are left.
     */
    public func unregisterService(withName name: String) {
        let serviceName = name.lowercased()
        logger.debug("Unregistering service: \(serviceName)", category: "LLMManager")

        services[serviceName] = nil

        if activeServiceName == serviceName {
            activeServiceName = services.keys.first
            logger.debug("Active service set to: \(self.activeServiceName ?? "nil")", category: "LLMManager")
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
            logger.error("Attempted to set active service to unknown service: \(name)", category: "LLMManager")
            return
        }
        activeServiceName = name
        logger.debug("Active service switched to: \(self.activeServiceName ?? "nil")", category: "LLMManager")
    }

    // MARK: - Route Request

    /**
     Routes a request to an appropriate LLM service based on the presence of a domain routing service and registered routings.

     - Parameters:
        - request: The `LLMRequest` object containing the prompt and configuration for the LLM.
        -  buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
        -  trimming: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.

     - Returns: An optional `LLMResponseProtocol` containing the response from the routed service.

     - Discussion:
     This function first checks if a domain routing service is available:
     - If a domain routing service exists, it uses the service to determine the appropriate domain for the request.
     - If no domain routing service is present, the function defaults to no routings (`[]`).

     Once the `routings` are determined, the function delegates to `sendRequest()`, which handles actual service selection and fallback logic.

     - Behavior:
        - **With a Domain Routing Service:** The request is sent to the routing service to identify the domain, and the result is used to create routing options.
        - **Without a Domain Routing Service:** The request is directly passed to `sendRequest()` with no routings (`[]`), defaulting to fallback logic if no matching services are found.

     - Example Usage:
        ```
        let response = await manager.routeRequest(myRequest)
        print(response?.text ?? "No response received")
        ```

     - Note: The `sendRequest()` method handles registered services and fallback logic, ensuring robust and flexible routing.
     */
    public func routeRequest(
        _ request: LLMRequest,
        buffer: Double = 0.05,
        trimming: String.TrimmingStrategy = .end
    ) async -> LLMResponseProtocol? {
        // Determine routings based on the presence of a domain routing service
        let routings: [Routing]
        if let domainRouter {
            logger.debug("Engaging domain router \(domainRouter.name) to determine appropriate domain...", category: "LLMManager")

            do {
                // Send the request to the domain router
                let domain = try await domainRouter.determineDomain(for: request)
                if !domain.isEmpty {
                    logger.debug("Domain routing service identified domain: \(domain)", category: "LLMManager")
                    routings = [.domain([domain])]
                } else {
                    logger.debug("Domain routing service returned an empty domain. Defaulting to fallback.", category: "LLMManager")
                    routings = []
                }
            } catch {
                logger.error("Domain routing service failed: \(error.localizedDescription)", category: "LLMManager")
                routings = [] // Default to no routings in case of error
            }
        } else {
            logger.debug("No domain routing service available. Defaulting to no routings.", category: "LLMManager")
            routings = [] // Default to no routings
        }

        // Call sendRequest with the determined routings
        return await sendRequest(request, routings: routings, buffer: buffer, trimming: trimming)
    }

    // MARK: - Send Request

    /**
     Sends a request to an LLM service, applying the specified routing and token trimming strategies if necessary.

     - Parameters:
        -  request: The `LLMRequest` containing the messages and parameters.
        -  routings: The routing options to select the appropriate service. Defaults to `[.inputTokenLimit(256)]`.
        -  buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
        -  trimming: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.

     - Returns: An optional `LLMResponseProtocol` object.

     This function trims the content if it exceeds the token limit of the selected service and sends the request.
     */
    public func sendRequest(
        _ request: LLMRequest,
        routings: [Routing] = [.inputTokenLimit(256)],
        buffer: Double = 0.05,
        trimming: String.TrimmingStrategy = .end
    ) async -> LLMResponseProtocol? {
        return await optimizeAndSendRequest(request, onPartialResponse: nil, routings: routings, buffer: buffer, trimming: trimming)
    }

    // MARK: - Streaming Request

    /**
     Sends a streaming request to an LLM service, applying the specified routing and token trimming strategies if necessary.

     - Parameters:
        -  request: The `LLMRequest` containing the messages and parameters.
        -  onPartialResponse: A closure that handles partial responses during streaming.
        -  routing: The routing options to select the appropriate service. Defaults to `[.inputTokenLimit(256)]`.
        -  buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
        -  trimming: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.

     - Returns: An optional `LLMResponseProtocol` object.

     This function trims the content if it exceeds the token limit of the selected service and sends the streaming request.
     */
    public func sendStreamingRequest(
        _ request: LLMRequest,
        onPartialResponse: ((String) -> Void)?,
        routings: [Routing] = [.inputTokenLimit(256)],
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
        return await optimizeAndSendRequest(streamingRequest, onPartialResponse: onPartialResponse, routings: routings, buffer: buffer, trimming: trimming)
    }

    // MARK: - Helper Methods

    /**
     Sends a streaming request to an LLM service, applying the specified routing and token trimming strategies if necessary.

     - Parameters:
        -  request: The `LLMRequest` containing the messages and parameters.
        -  onPartialResponse: A closure that handles partial responses during streaming.
        -  routing: The routing options to select the appropriate service. Defaults to `[.inputTokenLimit(256)]`.
        -  buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
        -  trimming: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.

     - Returns: An optional `LLMResponseProtocol` object.

     This function trims the content if it exceeds the token limit of the selected service and sends the streaming request.
     */
    private func optimizeAndSendRequest(
        _ request: LLMRequest,
        onPartialResponse: ((String) -> Void)?,
        routings: [Routing] = [.inputTokenLimit(256)],
        buffer: Double = 0.05,
        trimming: String.TrimmingStrategy = .end
    ) async -> LLMResponseProtocol? {
        logger.debug("Selecting service based on request...", category: "LLMManager")

        guard let selectedService = selectService(basedOn: routings, for: request, trimming: trimming) else {
            logger.error("No service available for the specified routing strategy.", category: "LLMManager")
            return nil
        }

        logger.debug("Sending request to service: \(selectedService.name), model: \(request.model ?? "Not specified")", category: "LLMManager")

        // Optimize request for the selected service
        logger.debug("Optimizing request for service...", category: "LLMManager")
        let optimizedRequest = optimizeRequest(request, for: selectedService, trimming: trimming, buffer: buffer)

        return await sendRequestToService(selectedService, withRequest: optimizedRequest, onPartialResponse: onPartialResponse)
    }

    /**
     Optimizes the `LLMRequest` to fit within the constraints of the selected service.

     - Parameters:
        -  request: The `LLMRequest` to optimize.
        -  service: The `LLMServiceProtocol` instance representing the selected service.
        -  trimming: The trimming strategy to apply when tokens exceed the limit.
        -  buffer: The buffer percentage to apply to the token limit, reducing the effective token limit slightly to allow for safer usage. Defaults to `0.05` (5%).

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
        logger.debug("Optimizing request for service \(service.name) with trimming strategy: \(trimming)", category: "LLMManager")

        // Adjust service-specific constraints with the buffer applied
        let adjustedContextWindow = Int(Double(service.contextWindowSize) * (1 - buffer))
        var adjustedMaxOutputTokens = Int(Double(service.maxOutputTokens) * (1 - buffer))

        // Estimate token count for the system prompt
        let systemPromptTokenCount = service.systemPrompt?.estimatedTokenCount() ?? 0

        // Calculate remaining token budget after reserving space for the system prompt
        let maxInputTokens = adjustedContextWindow - adjustedMaxOutputTokens - systemPromptTokenCount

        // Apply output token policy
        switch service.outputTokenPolicy {
        case .adjustToServiceLimits:
            adjustedMaxOutputTokens = min(request.maxTokens, adjustedMaxOutputTokens)
        case .strictRequestLimits:
            guard request.maxTokens <= adjustedMaxOutputTokens else {
                logger.debug("Strict output token limit enforced: \(request.maxTokens) exceeds \(adjustedMaxOutputTokens).", category: "LLMManager")
                return request
            }
        }

        // Trim messages if necessary
        var trimmedMessages: [LLMMessage]
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
                logger.debug("Strict input token limit enforced: \(request.estimatedTokenCount()) exceeds \(maxInputTokens).", category: "LLMManager")
                return request
            }
            trimmedMessages = request.messages
        }

        // Construct the final request by appending the system prompt if it exists
        if let systemPrompt = service.systemPrompt {
            logger.debug("Inserting system prompt for service \(service.name): \(systemPrompt.prefix(50))...", category: "LLMManager")
            trimmedMessages.insert(LLMMessage(role: .system, content: systemPrompt), at: 0)
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

     - Parameters:
        -  messages: The array of `LLMMessage` objects to trim.
        -  limit: The maximum token limit allowed for the message content.
        -  buffer: The buffer percentage to apply to the token limit.
        -  strategy: The trimming strategy to use if content exceeds the token limit.

     - Returns: An array of trimmed `LLMMessage` objects fitting within the token limit.
     */
    private func trimMessages(
        _ messages: [LLMMessage],
        toFitTokenLimit limit: Int,
        buffer: Double,
        strategy: String.TrimmingStrategy
    ) -> [LLMMessage] {
        var totalTokenCount = 0
        let adjustedLimit = Int(Double(limit) * (1 - buffer))

        return messages.map { message in
            let currentTokenCount = message.content.estimatedTokenCount()

            // Check if adding this message exceeds the budget
            if totalTokenCount + currentTokenCount > adjustedLimit {
                // Calculate remaining tokens in the budget
                let remainingTokens = adjustedLimit - totalTokenCount
                // Trim the message content to fit within the remaining budget
                let trimmedContent = message.content.trimmedToFit(
                    tokenLimit: remainingTokens,
                    buffer: 0.0, // Buffer was already accounted for in the adjusted limit
                    strategy: strategy
                )
                totalTokenCount += trimmedContent.estimatedTokenCount()
                return LLMMessage(role: message.role, content: trimmedContent)
            } else {
                // No trimming needed; add the full message
                totalTokenCount += currentTokenCount
                return message
            }
        }
    }

    /**
     Sends a request to a specific LLM service.

     - Parameters:
        -  service: The `LLMServiceProtocol` conforming service.
        -  request: The `LLMRequest` to send.
        -  onPartialResponse: A closure that handles partial responses during streaming (optional).
        -  isRetryingWithFallback: A flag indicating whether the request is a retry with a fallback service.

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
                logger.debug("Service succeeded with streaming response.", category: "LLMManager")
                return response
            } else {
                let response = try await service.sendRequest(request)
                logger.debug("Service succeeded with response.", category: "LLMManager")
                return response
            }
        } catch {
            // Log the failure
            logger.error("Service \(service.name) failed with error: \(error.localizedDescription)", category: "LLMManager")

            // Attempt to retry with a fallback service if available
            if let fallbackService, !isRetryingWithFallback {
                logger.debug("Retrying request with fallback service: \(fallbackService.name)", category: "LLMManager")
                return await sendRequestToService(fallbackService, withRequest: request, onPartialResponse: onPartialResponse, isRetryingWithFallback: true)
            }

            // If no fallback service is available or both fail, return nil
            logger.error("No fallback service succeeded or available after failure of \(service.name).", category: "LLMManager")
            return nil
        }
    }

    /**
     Chooses an LLM service based on the provided routing strategy.

     - Parameters:
        -  basedOn routings: The routing strategies to be applied for selection.
        -  request: The request being sent, used for analyzing compatibility.
        -  trimming: The trimming strategy to apply if tokens exceed the limit.

     - Returns: The `LLMServiceProtocol` that matches the given routing strategy, if available.
     */
    private func selectService(
        basedOn routings: [Routing],
        for request: LLMRequest,
        trimming: String.TrimmingStrategy = .none
    ) -> LLMServiceProtocol? {
        logger.debug("Selecting service based on multiple routing strategies: \(routings)", category: "LLMManager")

        // Sort services by routing specificity or priority
        let sortedServices = services.values.sorted { lhs, rhs in
            lhs.routings.count > rhs.routings.count // Prefer more specific services
        }

        // Step 1: Try the active service if it meets the criteria
        if let activeServiceName = activeServiceName,
           let activeService = services[activeServiceName]?.service,
           serviceMeetsCriteria(activeService, routings: routings, for: request, trimming: trimming) {
            logger.debug("Routing to active service: \(activeService.name)", category: "LLMManager")
            return activeService
        }

        // Step 2: Try any other matching service, excluding the active service
        if let matchingService = sortedServices.first(where: {
            $0.service.name.lowercased() != activeServiceName?.lowercased() &&
            serviceMeetsCriteria($0.service, routings: routings, for: request, trimming: trimming)
        })?.service {
            logger.debug("Routing to service matching strategies \(routings): \(matchingService.name)", category: "LLMManager")
            return matchingService
        }

        // Step 3: Attempt fallback routing if available
        if let fallbackService {
            logger.debug("Routing to fallback service: \(fallbackService.name)", category: "LLMManager")
            return fallbackService
        }

        // Step 4: No suitable service found
        logger.debug("No suitable service found for routing strategies \(routings), and no fallback available.", category: "LLMManager")
        return nil
    }

    /**
     Evaluates whether a given `LLMServiceProtocol` service meets the criteria specified by a routing strategy for the given request.

     - Parameters:
        -  service: The service being evaluated.
        -  routings: The routing strategies that specifies which criteria to evaluate.
        -  request: The `LLMRequest` providing details such as token count and maximum output tokens.

     - Returns: `true` if the service meets the criteria specified by the routing strategy; `false` otherwise.

     - Discussion:
        - Routing Criteria:
            - `inputTokenLimit`: Ensures that the input tokens in the request fit within the effective input token limit of the service.
            - `Domain`: Ensures that the service supports the specified domain(s).
        - `contextWindowSize` defines the total token budget for both input and output tokens.
        - `maxOutputTokens` defines the maximum allowable tokens for generating a response.
        - The function validates that the service's `contextWindowSize` can accommodate the sum of input and output tokens in the request and ensures `maxOutputTokens` is not exceeded.
     */
    private func serviceMeetsCriteria(
        _ service: LLMServiceProtocol,
        routings: [Routing],
        for request: LLMRequest,
        trimming: String.TrimmingStrategy = .none
    ) -> Bool {
        let apiKeyRequirementMet = !service.requiresAPIKey || service.apiKey != nil

        logger.debug("Evaluating service \(service.name) for multiple routing strategies: \(routings)", category: "LLMManager")

        for routing in routings {
            switch routing {
            case .inputTokenLimit(let limit):
                if !evaluateTokenLimits(service, request: request, limit: limit, trimming: trimming) {
                    return false
                }
            case .domain(let preferredDomains):
                if !evaluateDomainSupport(service, preferredDomains: preferredDomains) {
                    return false
                }
            }
        }

        return apiKeyRequirementMet
    }

    /**
     Evaluates whether a service meets the token limit requirements for a given request.

     - Parameters:
        - service: The `LLMServiceProtocol` instance representing the service being evaluated.
        - request: The `LLMRequest` containing the input tokens, output tokens, and other parameters.
        - limit: The input token limit for the routing strategy.
        - trimming: The trimming strategy to apply if tokens exceed the limit.

     - Returns: `true` if the service meets all token-related constraints (input tokens, output tokens, and context window size); `false` otherwise.

     This function validates the following:
       - Input tokens: Ensures the request's input tokens fit within the effective input token limit of the service.
       - Output tokens: Ensures the `maxTokens` in the request does not exceed the service's `maxOutputTokens`.
       - Context window: Verifies that the total token budget (input + output) fits within the service's `contextWindowSize`.
       - Adjustment policies: Applies the service's `TokenAdjustmentPolicy` for input and output tokens.
     */
    private func evaluateTokenLimits(
        _ service: LLMServiceProtocol,
        request: LLMRequest,
        limit: Int,
        trimming: String.TrimmingStrategy
    ) -> Bool {
        let originalInputTokens = request.estimatedTokenCount()
        var adjustedOutputTokens = request.maxTokens

        // Apply output token policy
        switch service.outputTokenPolicy {
        case .adjustToServiceLimits:
            if adjustedOutputTokens > service.maxOutputTokens {
                logger.debug("Warning: Adjusting output tokens to match service's limit (\(service.maxOutputTokens)).", category: "LLMManager")
                adjustedOutputTokens = service.maxOutputTokens
            }
        case .strictRequestLimits:
            if adjustedOutputTokens > service.maxOutputTokens {
                logger.debug("Strict limit enforced: Requested output tokens exceed service's limit.", category: "LLMManager")
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

        logger.debug("Service \(service.name) - Effective input token limit: \(effectiveInputTokenLimit), Effective output token limit: \(service.maxOutputTokens), Context window: \(service.contextWindowSize)", category: "LLMManager")
        logger.debug("Input tokens: \(originalInputTokens), Adjusted output tokens: \(adjustedOutputTokens), Total tokens required: \(totalOriginalTokens)", category: "LLMManager")
        logger.debug("Input token requirement met: \(inputTokenRequirementMet), Output token requirement met: \(outputTokenRequirementMet), Context window requirement met: \(contextWindowRequirementMet)", category: "LLMManager")

        return inputTokenRequirementMet && outputTokenRequirementMet && contextWindowRequirementMet
    }

    /**
     Evaluates whether a service supports the specified domains for routing.

     - Parameters:
        - service: The `LLMServiceProtocol` instance representing the service being evaluated.
        - preferredDomains: An array of preferred domains to be matched with the service's capabilities.

     - Returns: `true` if the service supports at least one of the preferred domains; `false` otherwise.

     - Discussion:
     This function compares the domains specified in the routing strategy with the service's registered domains.
     It ensures that the service can handle requests within the specified domain(s).

     - Notes:
       - Domain matching is case-insensitive.
       - Services can support multiple domains, and this function checks for intersection between the preferred domains and the service's supported domains.
     */
    private func evaluateDomainSupport(
        _ service: LLMServiceProtocol,
        preferredDomains: [String]
    ) -> Bool {
        let lowercasePreferredDomains = Set(preferredDomains.map { $0.lowercased() })
        let serviceDomains = services[service.name.lowercased()]?.routings.compactMap { option in
            if case let .domain(domains) = option { return domains.map { $0.lowercased() } }
            return nil
        }.flatMap { $0 } ?? []

        let serviceDomainsRequirementMet = lowercasePreferredDomains.isSubset(of: Set(serviceDomains))

        logger.debug("Service \(service.name) - Preferred domains: \(lowercasePreferredDomains), Service domains met: \(serviceDomainsRequirementMet)", category: "LLMManager")

        return serviceDomainsRequirementMet
    }
}
