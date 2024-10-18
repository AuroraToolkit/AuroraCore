//
//  LLMManager.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 8/19/24.
//

import Foundation
import os.log

/**
 `LLMManager` is responsible for managing multiple Language Learning Model (LLM) services, handling requests, routing, and fallback mechanisms.
 It allows registering services, sending requests, and managing token usage with trimming strategies.
 */
public class LLMManager {

    /// A logger for recording information and errors within the `LLMManager`.
    private let logger = Logger(subsystem: "com.mutantsoup.AuroraCore", category: "LLMManager")

    /// A dictionary mapping service names to their respective `LLMServiceProtocol` instances.
    private(set) var services: [String: LLMServiceProtocol] = [:]

    /// The name of the currently active service.
    private(set) var activeServiceName: String?

    // MARK: - Register Services

    /**
     Registers a new LLM service with a specified name.

     - Parameters:
        - service: The service conforming to `LLMServiceProtocol` to be registered.
        - name: The name under which to register the service.
     */
    public func registerService(_ service: LLMServiceProtocol, withName name: String) {
        logger.log("Registering service: \(name, privacy: .public)")
        services[name] = service

        // Set as active service if no active service is set
        if activeServiceName == nil {
            activeServiceName = name
            logger.log("Active service set to: \(name, privacy: .public)")
        }
    }

    // MARK: - Set Active Service

    /**
     Sets the active LLM service by its registered name.

     - Parameter name: The name of the service to be set as active.
     */
    public func setActiveService(byName name: String) {
        guard services[name] != nil else {
            logger.error("Attempted to set active service to unknown service: \(name, privacy: .public)")
            return
        }
        activeServiceName = name
        logger.log("Active service switched to: \(name, privacy: .public)")
    }

    // MARK: - Send Request

    /**
     Sends a request to the active LLM service, applying token trimming strategies if necessary.

     - Parameters:
        - request: The `LLMRequest` containing the messages and parameters.
        - buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
        - strategy: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.
     - Returns: An optional `LLMResponseProtocol` object.
     */
    public func sendRequest(
        _ request: LLMRequest,
        buffer: Double = 0.05,
        strategy: String.TrimmingStrategy = .end
    ) async -> LLMResponseProtocol? {
        guard let activeServiceName = activeServiceName, let service = services[activeServiceName] else {
            logger.error("No active service available to handle the request.")
            return nil
        }

        logger.log("Sending request to active service: \(activeServiceName, privacy: .public)")

        let trimmedMessages = trimMessages(request.messages, toFitTokenLimit: service.maxTokenLimit, buffer: buffer, strategy: strategy)
        let optimizedRequest = LLMRequest(messages: trimmedMessages, model: request.model)

        return await sendRequestToService(service, withRequest: optimizedRequest)
    }

    // MARK: - Streaming Request

    /**
     Sends a streaming request to the active LLM service, applying token trimming strategies if necessary.

     - Parameters:
        - request: The `LLMRequest` containing the messages and parameters.
        - onPartialResponse: A closure that handles partial responses during streaming.
        - buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
        - strategy: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.
     - Returns: An optional `LLMResponseProtocol` object.
     */
    public func sendStreamingRequest(
        _ request: LLMRequest,
        onPartialResponse: ((String) -> Void)?,
        buffer: Double = 0.05,
        strategy: String.TrimmingStrategy = .end
    ) async -> LLMResponseProtocol? {
        guard let activeServiceName = activeServiceName, let service = services[activeServiceName] else {
            logger.error("No active service available to handle the streaming request.")
            return nil
        }

        logger.log("Sending streaming request to active service: \(activeServiceName, privacy: .public)")

        let trimmedMessages = trimMessages(request.messages, toFitTokenLimit: service.maxTokenLimit, buffer: buffer, strategy: strategy)
        let optimizedRequest = LLMRequest(messages: trimmedMessages, model: request.model)

        return await sendRequestToService(service, withRequest: optimizedRequest, onPartialResponse: onPartialResponse)
    }

    // MARK: - Hybrid Routing

    /**
     Sends a request to a service chosen by the provided routing strategy.

     - Parameters:
        - request: The `LLMRequest` containing the messages and parameters.
        - strategy: A closure that selects a service name based on the request.
        - buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
        - trimmingStrategy: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.
     - Returns: An optional `LLMResponseProtocol` object.
     */
    public func sendRequestWithRouting(
        _ request: LLMRequest,
        usingRoutingStrategy strategy: @escaping (LLMRequest) -> String?,
        buffer: Double = 0.05,
        trimmingStrategy: String.TrimmingStrategy = .end
    ) async -> LLMResponseProtocol? {
        if let selectedServiceName = strategy(request),
           let selectedService = services[selectedServiceName] {

            logger.log("Routing request to service: \(selectedServiceName, privacy: .public)")

            let trimmedMessages = trimMessages(request.messages, toFitTokenLimit: selectedService.maxTokenLimit, buffer: buffer, strategy: trimmingStrategy)
            let optimizedRequest = LLMRequest(messages: trimmedMessages, model: request.model)

            return await sendRequestToService(selectedService, withRequest: optimizedRequest)
        } else {
            logger.log("Routing strategy failed. Falling back to active service.")
            return await sendRequest(request, buffer: buffer, strategy: trimmingStrategy)
        }
    }

    // MARK: - Fallback Mechanism

    /**
     Sends a request to the active service, with a fallback to another service if the request fails.

     - Parameters:
        - request: The `LLMRequest` containing the messages and parameters.
        - fallbackServiceName: The name of the service to fall back to if the active service fails.
        - buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
        - strategy: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.
     - Returns: An optional `LLMResponseProtocol` object.
     */
    public func sendRequestWithFallback(
        _ request: LLMRequest,
        fallbackServiceName: String,
        buffer: Double = 0.05,
        strategy: String.TrimmingStrategy = .end
    ) async -> LLMResponseProtocol? {
        logger.log("Attempting request with active service first.")
        if let response = await sendRequest(request, buffer: buffer, strategy: strategy) {
            logger.log("Active service succeeded.")
            return response
        } else {
            logger.error("Active service failed. Attempting fallback service: \(fallbackServiceName, privacy: .public)")
            if let fallbackService = services[fallbackServiceName] {

                let trimmedMessages = trimMessages(request.messages, toFitTokenLimit: fallbackService.maxTokenLimit, buffer: buffer, strategy: strategy)
                let optimizedRequest = LLMRequest(messages: trimmedMessages, model: request.model)

                return await sendRequestToService(fallbackService, withRequest: optimizedRequest)
            } else {
                logger.error("Fallback service not found: \(fallbackServiceName, privacy: .public)")
                return nil
            }
        }
    }

    // MARK: - Helper Methods

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
     - Returns: An optional `LLMResponseProtocol` object.
     */
    private func sendRequestToService(
        _ service: LLMServiceProtocol,
        withRequest request: LLMRequest,
        onPartialResponse: ((String) -> Void)? = nil
    ) async -> LLMResponseProtocol? {
        do {
            if let onPartialResponse = onPartialResponse {
                let response = try await service.sendRequest(request, onPartialResponse: onPartialResponse)
                logger.log("Service succeeded with streaming response.")
                return response
            } else {
                let response = try await service.sendRequest(request)
                logger.log("Service succeeded with response.")
                return response
            }
        } catch {
            logger.error("Service failed with error: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
