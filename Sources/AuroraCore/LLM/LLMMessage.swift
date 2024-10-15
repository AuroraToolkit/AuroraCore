//
//  LLMMessage.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 10/14/24.
//

import Foundation

/**
 Represents the role of a message sender within a conversation.

 This enum defines common roles that can be used when sending messages to the LLM.
 The roles help provide context for the conversation and can influence the behavior of the LLM.
 */
public enum LLMRole: Codable, Equatable {
    case user
    case assistant
    case system
    case custom(String)

    /// Returns the string value of the role, either predefined or custom.
    public var rawValue: String {
        switch self {
        case .user:
            return "user"
        case .assistant:
            return "assistant"
        case .system:
            return "system"
        case .custom(let role):
            return role
        }
    }

    // Custom encoding to handle associated value for the `.custom` case
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .user:
            try container.encode("user")
        case .assistant:
            try container.encode("assistant")
        case .system:
            try container.encode("system")
        case .custom(let role):
            try container.encode(role)
        }
    }

    // Custom decoding to handle associated value for the `.custom` case
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch rawValue {
        case "user":
            self = .user
        case "assistant":
            self = .assistant
        case "system":
            self = .system
        default:
            if rawValue.starts(with: "{") {
                let customRole = try container.decode([String: String].self)
                self = .custom(customRole["custom"] ?? "unknown")
            } else {
                self = .custom(rawValue)
            }
        }
    }
}

/**
 Represents a single message within a conversation for LLM interactions.

 `LLMMessage` instances capture both user inputs and responses from the LLM. They help provide context
 for multi-turn conversations, allowing the LLM to generate more coherent and contextually aware responses.
 */
public struct LLMMessage: Codable, Equatable {
    /// The role of the message sender, such as "user", "assistant", or "system".
    public var role: LLMRole
    /// The content of the message, containing the actual text or instructions.
    public var content: String

    /**
     Initializes a new `LLMMessage` instance.

     - Parameters:
       - role: The role of the message sender, including custom roles as needed.
       - content: The message content or text.
     */
    public init(role: LLMRole, content: String) {
        self.role = role
        self.content = content
    }
}
