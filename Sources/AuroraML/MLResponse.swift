//
//  MLResponse.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/4/25.
//

import Foundation

/**
    The `MLResponse` struct encapsulates the outputs from an on-device ML model. It is designed to hold arbitrary data
    in a dictionary format, allowing for flexibility in the type of outputs that can be returned.
 */
public struct MLResponse {
    /// Arbitrary output data, e.g. classifications, scores, embeddings.
    public let outputs: [String: Any]

    /// Optional metadata (timings, model version).
    public let info: [String: Any]?

    /**
        Initializes a new `MLResponse` instance.

        - Parameters:
            - outputs: A dictionary containing the model's outputs.
            - info: Optional metadata about the model or the response.
     */
    public init(outputs: [String: Any],
                info: [String: Any]? = nil)
    {
        self.outputs = outputs
        self.info = info
    }
}
