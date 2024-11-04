//
//  LLMRequestOptions.swift
//
//  Created by Dan Murrell Jr on 10/5/24.
//

import Foundation

/**
 `LLMRequestOptions` provides a way to configure additional options for LLM requests in a structured manner.
 This struct encapsulates less common parameters that can be used to further customize the behavior of the language model.
 */
public struct LLMRequestOptions {
    /// Nucleus sampling parameter that limits sampling to the top percentile of tokens. Lower values narrow the scope of the sampling to the most likely tokens.
    public var topP: Double?

    /// A penalty applied to reduce the repetition of the same tokens in the response.
    public var frequencyPenalty: Double?

    /// A penalty applied to encourage the introduction of new tokens into the response, promoting variety.
    public var presencePenalty: Double?

    /// Sequences of tokens that signal the LLM to stop generating further tokens when encountered in the response.
    public var stopSequences: [String]?

    /// A map of token biases, allowing customization of the likelihood of specific tokens appearing in the response.
    public var logitBias: [String: Double]?

    /// An optional user identifier, which can be used for tracking, moderation, or specific user-based adjustments.
    public var user: String?

    /// The suffix to add to the generated text (if applicable).
    public var suffix: String?

    /// Preferred domains for the request, used for selecting the most suitable service during routing.
    public var preferredDomains: [String]?

    /**
     Initializes a new `LLMRequestOptions` with default values for all fields.

     - Parameters:
        - topP: The top probability value used for nucleus sampling.
        - frequencyPenalty: A penalty to discourage token repetition in the response.
        - presencePenalty: A penalty to encourage the introduction of new tokens in the response.
        - stopSequences: An optional array of strings that will stop the response generation when encountered.
        - logitBias: An optional dictionary that maps tokens to biases, allowing adjustment of token probabilities.
        - user: An optional string representing a user identifier for tracking purposes.
        - suffix: An optional string that will be added after the model's response.
        - preferredDomains: An optional array of strings representing preferred domains for routing.
     */
    public init(
        topP: Double? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        stopSequences: [String]? = nil,
        logitBias: [String: Double]? = nil,
        user: String? = nil,
        suffix: String? = nil,
        preferredDomains: [String]? = nil
    ) {
        self.topP = topP
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.stopSequences = stopSequences
        self.logitBias = logitBias
        self.user = user
        self.suffix = suffix
        self.preferredDomains = preferredDomains
    }
}
