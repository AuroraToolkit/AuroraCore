//
//  MLRequest.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/4/25.
//

import Foundation

/**
    * `MLRequest` is a structure that encapsulates the inputs and optional parameters for an ML model request.
 */
public struct MLRequest {
    /// Arbitrary input data, e.g. text, tokenized features, image buffers, etc.
    public let inputs: [String: Any]

    /// Optional runtime parameters (e.g. confidence thresholds, batch size).
    public let options: [String: Any]?

    /**
        Initializes a new `MLRequest` with the specified inputs and options.

        - Parameters:
            - inputs: A dictionary of input data for the ML model.
            - options: Optional parameters to customize the ML request.
     */
    public init(inputs: [String: Any],
                options: [String: Any]? = nil)
    {
        self.inputs = inputs
        self.options = options
    }
}
