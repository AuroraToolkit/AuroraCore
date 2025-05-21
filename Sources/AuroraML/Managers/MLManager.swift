//
//  MLManager.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/4/25.
//

import AuroraCore
import Foundation

/**
 `MLManager` is responsible for registering and managing multiple on-device ML models.

 It allows registering, unregistering, selecting, and running inference on models.

 ### Example
 ```swift
 let mlManager = MLManager()

 // Register two sentiment models
 mlManager.register(tinySentiment) // CoreMLService(name: "sentiment-tiny")
 mlManager.register(largeSentiment) // CoreMLService(name: "sentiment-large")

 // Run inference on the tiny model
 let request = MLRequest(inputs: ["text": "I love this!"])
 let response = try await mlManager.run(name: "sentiment-tiny", request: request)
 print(response.outputs["sentiment"] as? String)  // e.g. "Positive"
 ```
 */
public final actor MLManager {
    /// An optional logger for recording information and errors within the `LLMManager`.
    private let logger: CustomLogger?

    /// Dictionary to hold registered ML services.
    private(set) var services: [String: MLServiceProtocol] = [:]

    /// Computed property to get all registered service names.
    public var registeredServiceNames: [String] {
        Array(services.keys)
    }

    /// The name of the currently active service.
    private(set) var activeServiceName: String?

    /// The designated fallback service.
    private(set) var fallbackService: MLServiceProtocol?

    /**
        Initializes a new `MLManager` instance.

        - Parameter logger: An optional logger for recording information and errors.
     */
    public init(logger: CustomLogger? = nil) {
        self.logger = logger
    }

    // MARK: - Registering Services

    /**
     Registers a new fallback ML service or replaces an existing one.

     - Parameter service: The service conforming to `MLServiceProtocol` to be registered as a fallback.
     */
    public func registerFallbackService(_ service: MLServiceProtocol) {
        if fallbackService != nil {
            logger?.debug("Replacing existing fallback service with name '\(service.name)'", category: "MLManager")
        } else {
            logger?.debug("Registering new fallback service with name '\(service.name)'", category: "MLManager")
        }

        fallbackService = service
    }

    /**
        Unregisters the fallback service.
     */
    public func unregisterFallbackService() {
        fallbackService = nil
        logger?.debug("Cleared fallback service", category: "MLManager")
    }

    /**
     Register an ML service under a key.

     - Parameters:
     - service: The `MLServiceProtocol` implementation.
     - key: A unique identifier for the model.

     If a service with the same name already exists, it is replaced.
     */
    public func register(_ service: MLServiceProtocol) {
        let serviceName = service.name.lowercased()

        if services[serviceName] != nil {
            logger?.debug("Replacing existing service with name '\(serviceName)'", category: "MLManager")
        } else {
            logger?.debug("Registering new service with name '\(serviceName)'", category: "MLManager")
        }

        services[serviceName] = service

        if activeServiceName == nil {
            activeServiceName = serviceName
            logger?.debug("Active service set to: \(activeServiceName ?? "nil")", category: "MLManager")
        }
    }

    /**
        Unregister a service by its name.
        - Parameter name: The name of the service.
     */
    public func unregisterService(withName name: String) {
        let serviceName = name.lowercased()
        logger?.debug("Unregistering service: \(serviceName)", category: "MLManager")

        services[serviceName] = nil
    }

    /**
     Retrieve a registered ML service.

     - Parameter name: The service name.
     - Throws: An error if no service is found.
     - Returns: The `MLServiceProtocol` instance.
     */
    public func service(forName name: String) throws -> MLServiceProtocol {
        let serviceName = name.lowercased()
        guard let service = services[serviceName] else {
            throw NSError(
                domain: "MLManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey:
                    "No ML service registered for '\(serviceName)'"]
            )
        }

        logger?.debug("Retrieved service: \(serviceName)", category: "MLManager")
        return service
    }

    // MARK: - Set Active Service

    /**
     Sets the active ML service by its registered name.

     - Parameter name: The name of the service to be set as active.

     Logs an error if the specified name does not correspond to a registered service.
     */
    public func setActiveService(byName name: String) throws {
        guard services[name.lowercased()] != nil else {
            throw NSError(
                domain: "MLManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey:
                    "Cannot set active service to unregistered '\(name)'"]
            )
        }

        activeServiceName = name
        logger?.debug("Active service switched to: \(activeServiceName ?? "nil")", category: "MLManager")
    }

    // MARK: - Run model inference

    /**
     Run inference on the active service.

     - Parameter request: The `MLRequest` inputs.
     - Throws: If no active service is set or inference fails.
     - Returns: An `MLResponse` with the service's outputs.
     */
    public func run(request: MLRequest) async throws -> MLResponse {
        guard let name = activeServiceName else {
            throw NSError(
                domain: "MLManager",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey:
                    "No active ML service selected"]
            )
        }
        return try await run(name, request: request)
    }

    /**
     Run a request on a named model.

     - Parameters:
     - name: The name of the registered ML service.
     - request: The `MLRequest` containing inputs.
     - Throws: Errors from lookup or inference.
     - Returns: An `MLResponse` with the service's outputs.
     */
    public func run(_ name: String, request: MLRequest) async throws -> MLResponse {
        logger?.debug("Running ML service: \(name)", category: "MLManager")
        let serviceName = name.lowercased()
        do {
            let service = try service(forName: serviceName)
            return try await service.run(request: request)
        } catch {
            logger?.error("Failed to run ML service '\(serviceName)', attempting fallback': \(error)", category: "MLManager")
            if let fallbackService {
                return try await fallbackService.run(request: request)
            }
            throw error
        }
    }
}
