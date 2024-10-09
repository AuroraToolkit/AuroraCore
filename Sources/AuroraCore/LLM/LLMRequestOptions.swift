//
//  LLMRequestOptions.swift
//
//  Created by Dan Murrell Jr on 10/5/24.
//

import Foundation

/**
 `LLMRequestOptions` provides a way to configure LLM requests in a structured and type-safe manner.
 This struct encapsulates all available options that can be used to customize the behavior of the language model.
 */
public struct LLMRequestOptions {
    /// The sampling temperature to control randomness (values between 0.0 to 1.0).
    /// Higher values (e.g., 1.0) make the output more random, while lower values (e.g., 0.0) make it more deterministic.
    public var temperature: Double?

    /// The maximum number of tokens in the generated response.
    public var maxTokens: Int?

    /// Nucleus sampling parameter that limits sampling to the top percentile of tokens.
    /// Lower values narrow the scope of the sampling to the most likely tokens.
    public var topP: Double?

    /// A penalty applied to reduce the repetition of the same tokens in the response.
    public var frequencyPenalty: Double?

    /// A penalty applied to encourage the introduction of new tokens into the response, promoting variety.
    public var presencePenalty: Double?

    /// Sequences of tokens that signal the LLM to stop generating further tokens when encountered in the response.
    public var stopSequences: [String]?

    /// The specific LLM model to use for processing (e.g., "gpt-3.5-turbo", "davinci").
    /// If not specified, the default model for the service will be used.
    public var model: String?

    /// A map of token biases, allowing customization of the likelihood of specific tokens appearing in the response.
    public var logitBias: [String: Double]?

    /// An optional user identifier, which can be used for tracking, moderation, or specific user-based adjustments.
    public var user: String?

    /// The suffix to add to the generated text (if applicable).
    public var suffix: String?

    /// Whether or not to stream the response.
    public var stream: Bool?

    /**
     Initializes a new `LLMRequestOptions` with default values for all fields.
     - Parameters:
        - temperature: A value between 0.0 and 1.0 controlling the randomness of the response.
        - maxTokens: The maximum number of tokens to generate in the response.
        - topP: The top probability value used for nucleus sampling.
        - frequencyPenalty: A penalty to discourage token repetition in the response.
        - presencePenalty: A penalty to encourage the introduction of new tokens in the response.
        - stopSequences: An optional array of strings that will stop the response generation when encountered.
        - model: An optional string representing the model to use.
        - logitBias: An optional dictionary that maps tokens to biases, allowing adjustment of token probabilities.
        - user: An optional string representing a user identifier for tracking purposes.
        - suffix: An optional string that will be added after the model's response.
        - stream: Whether or not the response should be streamed.
     */
    public init(
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        stopSequences: [String]? = nil,
        model: String? = nil,
        logitBias: [String: Double]? = nil,
        user: String? = nil,
        suffix: String? = nil,
        stream: Bool? = nil
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.stopSequences = stopSequences
        self.model = model
        self.logitBias = logitBias
        self.user = user
        self.suffix = suffix
        self.stream = stream
    }
}
