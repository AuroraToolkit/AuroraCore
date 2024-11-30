//
//  SummarizerOptions.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 10/16/24.
//

import Foundation

/**
 `SummarizerOptions` provides a way to configure options specifically for summarization tasks.
 This struct encapsulates parameters that influence how the summary is generated.
 */
public struct SummarizerOptions {
    /// The sampling temperature to control randomness (values between 0.0 to 1.0).
    public var temperature: Double?

    /// The maximum number of tokens in the generated summary.
    public var maxTokens: Int?

    /// The specific LLM model to use for summarization (e.g., "gpt-3.5-turbo").
    public var model: String?

    /// Whether or not to stream the response (default is `false`).
    public var stream: Bool?

    /**
     Initializes a new `SummarizerOptions` with default values for all fields.

     - Parameters:
        - temperature: A value between 0.0 and 1.0 controlling the randomness of the summary.
        - maxTokens: The maximum number of tokens to generate in the summary.
        - model: An optional string representing the model to use.
        - stream: Whether or not the summary should be streamed.
     */
    public init(
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        model: String? = nil,
        stream: Bool? = nil
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.model = model
        self.stream = stream
    }
}
