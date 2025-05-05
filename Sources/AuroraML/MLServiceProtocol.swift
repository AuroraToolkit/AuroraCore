//
//  MLServiceProtocol.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/4/25.
//

import Foundation

/**
 The `MLServiceProtocol`defines  the behavior of a machine learning service  (Core ML, Natural Language, etc.).

 This protocol ensures that all ML services handle requests and responses consistently, allowing the client to interact with multiple ML models in a unified way.
 */
public protocol MLServiceProtocol {
    /**
     The name of the service instance, which can be customized during initialization
     */
    var name: String { get set }

    /**
     Run the given request through the model and return its response.

        - Parameters:
            - request: The `MLRequest` containing the input features and options for the model.

        - Returns: A `MLResponse` containing the model outputs and optional metadata.
        - Throws: An error if there is an issue during inference or pre/post-processing.
     */
    func run(request: MLRequest) async throws -> MLResponse
}
