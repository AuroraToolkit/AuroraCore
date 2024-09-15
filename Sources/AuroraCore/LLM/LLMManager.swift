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
        - request: The `LLMRequest` containing the prompt and parameters.
        - context: An optional string context to be included with the prompt.
        - buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
        - strategy: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.
        - completion: A closure that receives an optional `LLMResponse`.
     */
    public func sendRequest(
        _ request: LLMRequest,
        context: String? = nil,
        buffer: Double = 0.05,
        strategy: String.TrimmingStrategy = .end,
        completion: @escaping (LLMResponseProtocol?) -> Void
    ) {
        guard let activeServiceName = activeServiceName, let service = services[activeServiceName] else {
            logger.error("No active service available to handle the request.")
            completion(nil)
            return
        }

        logger.log("Sending request to active service: \(activeServiceName, privacy: .public)")

        // Trim tokens if necessary
        let trimmedPrompt = request.prompt.trimmedToFit(
            tokenLimit: service.maxTokenLimit,
            buffer: buffer,
            strategy: strategy
        )
        let optimizedRequest = LLMRequest(prompt: trimmedPrompt)

        self.sendRequestToService(service, withRequest: optimizedRequest, completion: completion)
    }

    // MARK: - Async Send Request

    /**
     Sends a request to the active LLM service asynchronously, applying token trimming strategies if necessary.

     - Parameters:
        - request: The `LLMRequest` containing the prompt and parameters.
        - context: An optional string context to be included with the prompt.
        - buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
        - strategy: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.
     - Returns: An optional `LLMResponseProtocol` object.
     */
    public func sendRequestAsync(
        _ request: LLMRequest,
        context: String? = nil,
        buffer: Double = 0.05,
        strategy: String.TrimmingStrategy = .end
    ) async -> LLMResponseProtocol? {
        guard let activeServiceName = activeServiceName, let service = services[activeServiceName] else {
            logger.error("No active service available to handle the request.")
            return nil
        }

        logger.log("Sending request to active service: \(activeServiceName, privacy: .public)")

        // Trim tokens if necessary
        let trimmedPrompt = request.prompt.trimmedToFit(
            tokenLimit: service.maxTokenLimit,
            buffer: buffer,
            strategy: strategy
        )
        let optimizedRequest = LLMRequest(prompt: trimmedPrompt)

        return await self.sendRequestToServiceAsync(service, withRequest: optimizedRequest)
    }

    // MARK: - Hybrid Routing

    /**
     Sends a request to a service chosen by the provided routing strategy.

     - Parameters:
        - request: The `LLMRequest` containing the prompt and parameters.
        - strategy: A closure that selects a service name based on the request.
        - buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
        - trimmingStrategy: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.
        - completion: A closure that receives an optional `LLMResponseProtocol`.
     */
    public func sendRequestWithRouting(
        _ request: LLMRequest,
        usingRoutingStrategy strategy: @escaping (LLMRequest) -> String?,
        buffer: Double = 0.05,
        trimmingStrategy: String.TrimmingStrategy = .end,
        completion: @escaping (LLMResponseProtocol?) -> Void
    ) {
        if let selectedServiceName = strategy(request),
           let selectedService = services[selectedServiceName] {

            logger.log("Routing request to service: \(selectedServiceName, privacy: .public)")

            // Trim tokens if necessary
            let trimmedPrompt = request.prompt.trimmedToFit(
                tokenLimit: selectedService.maxTokenLimit,
                buffer: buffer,
                strategy: trimmingStrategy
            )
            let optimizedRequest = LLMRequest(prompt: trimmedPrompt)

            self.sendRequestToService(selectedService, withRequest: optimizedRequest, completion: completion)
        } else {
            logger.log("Routing strategy failed. Falling back to active service.")
            self.sendRequest(request, buffer: buffer, strategy: trimmingStrategy, completion: completion)
        }
    }

    // MARK: - Async Hybrid Routing

    /**
     Sends a request to a service chosen by the provided routing strategy asynchronously.

     - Parameters:
        - request: The `LLMRequest` containing the prompt and parameters.
        - strategy: A closure that selects a service name based on the request.
        - buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
        - trimmingStrategy: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.
     - Returns: An optional `LLMResponseProtocol` object.
     */
    public func sendRequestWithRoutingAsync(
        _ request: LLMRequest,
        usingRoutingStrategy strategy: @escaping (LLMRequest) -> String?,
        buffer: Double = 0.05,
        trimmingStrategy: String.TrimmingStrategy = .end
    ) async -> LLMResponseProtocol? {
        if let selectedServiceName = strategy(request),
           let selectedService = services[selectedServiceName] {

            logger.log("Routing request to service: \(selectedServiceName, privacy: .public)")

            // Trim tokens if necessary
            let trimmedPrompt = request.prompt.trimmedToFit(
                tokenLimit: selectedService.maxTokenLimit,
                buffer: buffer,
                strategy: trimmingStrategy
            )
            let optimizedRequest = LLMRequest(prompt: trimmedPrompt)

            return await self.sendRequestToServiceAsync(selectedService, withRequest: optimizedRequest)
        } else {
            logger.log("Routing strategy failed. Falling back to active service.")
            return await self.sendRequestAsync(request, buffer: buffer, strategy: trimmingStrategy)
        }
    }

    // MARK: - Fallback Mechanism

    /**
     Sends a request to the active service, with a fallback to another service if the request fails.

     - Parameters:
        - request: The `LLMRequest` containing the prompt and parameters.
        - fallbackServiceName: The name of the service to fall back to if the active service fails.
        - buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
        - strategy: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.
        - completion: A closure that receives an optional `LLMResponseProtocol`.
     */
    public func sendRequestWithFallback(
        _ request: LLMRequest,
        fallbackServiceName: String,
        buffer: Double = 0.05,
        strategy: String.TrimmingStrategy = .end,
        completion: @escaping (LLMResponseProtocol?) -> Void
    ) {
        logger.log("Attempting request with active service first.")
        sendRequest(request, buffer: buffer, strategy: strategy) { response in
            if let response = response {
                self.logger.log("Active service succeeded.")
                completion(response)
            } else {
                self.logger.error("Active service failed. Attempting fallback service: \(fallbackServiceName, privacy: .public)")
                if let fallbackService = self.services[fallbackServiceName] {

                    // Trim tokens if necessary
                    let trimmedPrompt = request.prompt.trimmedToFit(
                        tokenLimit: fallbackService.maxTokenLimit,
                        buffer: buffer,
                        strategy: strategy
                    )
                    let optimizedRequest = LLMRequest(prompt: trimmedPrompt)

                    self.sendRequestToService(fallbackService, withRequest: optimizedRequest, completion: completion)
                } else {
                    self.logger.error("Fallback service not found: \(fallbackServiceName, privacy: .public)")
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Async Fallback Mechanism

    /**
     Sends a request to the active service asynchronously, with a fallback to another service if the request fails.

     - Parameters:
        - request: The `LLMRequest` containing the prompt and parameters.
        - fallbackServiceName: The name of the service to fall back to if the active service fails.
        - buffer: The buffer percentage to apply to the token limit. Defaults to 0.05 (5%).
        - strategy: The trimming strategy to apply when tokens exceed the limit. Defaults to `.end`.
     - Returns: An optional `LLMResponseProtocol` object.
     */
    public func sendRequestWithFallbackAsync(
        _ request: LLMRequest,
        fallbackServiceName: String,
        buffer: Double = 0.05,
        strategy: String.TrimmingStrategy = .end
    ) async -> LLMResponseProtocol? {
        logger.log("Attempting request with active service first.")
        if let response = await sendRequestAsync(request, buffer: buffer, strategy: strategy) {
            logger.log("Active service succeeded.")
            return response
        } else {
            logger.error("Active service failed. Attempting fallback service: \(fallbackServiceName, privacy: .public)")
            if let fallbackService = services[fallbackServiceName] {

                // Trim tokens if necessary
                let trimmedPrompt = request.prompt.trimmedToFit(
                    tokenLimit: fallbackService.maxTokenLimit,
                    buffer: buffer,
                    strategy: strategy
                )
                let optimizedRequest = LLMRequest(prompt: trimmedPrompt)

                return await self.sendRequestToServiceAsync(fallbackService, withRequest: optimizedRequest)
            } else {
                logger.error("Fallback service not found: \(fallbackServiceName, privacy: .public)")
                return nil
            }
        }
    }

    // MARK: - Helper Methods

    /**
     Sends a request to a specific LLM service.

     - Parameters:
        - service: The `LLMServiceProtocol` conforming service.
        - request: The `LLMRequest` to send.
        - completion: A closure that receives an optional `LLMResponseProtocol`.
     */
    private func sendRequestToService(_ service: LLMServiceProtocol, withRequest request: LLMRequest, completion: @escaping (LLMResponseProtocol?) -> Void) {
        service.sendRequest(request) { [weak self] result in
            switch result {
            case .success(let response):
                self?.logger.log("Service succeeded with response: \(response.text, privacy: .public)")
                completion(response)
            case .failure(let error):
                self?.logger.error("Service failed with error: \(error.localizedDescription, privacy: .public)")
                completion(nil)
            }
        }
    }

    /**
     Sends a request to a specific LLM service asynchronously.

     - Parameters:
        - service: The `LLMServiceProtocol` conforming service.
        - request: The `LLMRequest` to send.
     - Returns: An optional `LLMResponseProtocol` object.
     */
    private func sendRequestToServiceAsync(_ service: LLMServiceProtocol, withRequest request: LLMRequest) async -> LLMResponseProtocol? {
        do {
            let response = try await service.sendRequest(request)
            logger.log("Service succeeded with response: \(response.text, privacy: .public)")
            return response
        } catch {
            logger.error("Service failed with error: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
