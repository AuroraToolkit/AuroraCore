//
//  GoogleGenerateContentRequest.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 4/3/25.
//

import Foundation

// MARK: - Google API Request Structures

struct GoogleGenerateContentRequest: Codable {
    let contents: [GoogleContent]
    let systemInstruction: GoogleContent?
    let generationConfig: GoogleGenerationConfig?
    let safetySettings: [GoogleSafetySetting]? // Optional safety settings
}

struct GoogleContent: Codable {
    // Role is optional for systemInstruction, required for contents
    let role: String?
    let parts: [GooglePart]
}

struct GooglePart: Codable {
    let text: String
    // Future: Add other part types like inlineData (for images/files) if needed
    // struct InlineData: Codable { let mimeType: String; let data: String }
    // let inlineData: InlineData?
}

struct GoogleGenerationConfig: Codable {
    let temperature: Double?
    let topP: Double?
    let maxOutputTokens: Int?
    let stopSequences: [String]?
    // Add other config params like topK if needed
}

struct GoogleSafetySetting: Codable {
    let category: String // e.g., "HARM_CATEGORY_SEXUALLY_EXPLICIT"
    let threshold: String // e.g., "BLOCK_MEDIUM_AND_ABOVE"
}

// MARK: - Google API Response Structures

// Main response structure (non-streaming and final streaming)
struct GoogleGenerateContentResponse: LLMResponseProtocol, Codable {
    var vendor: String? = "Google"
    var model: String? // Should be injected by GoogleService after the request

    let candidates: [GoogleCandidate]?
    let usageMetadata: GoogleUsageMetadata?
    let promptFeedback: GooglePromptFeedback? // Optional feedback

    // LLMResponseProtocol Conformance
    var text: String {
        // Concatenate text from all parts in the first candidate's content
        candidates?.first?.content.parts.compactMap { $0.text }.joined() ?? ""
    }

    var tokenUsage: LLMTokenUsage? {
        guard let metadata = usageMetadata else { return nil }
        // Note: Gemini API uses 'candidatesTokenCount' for completion tokens.
        return LLMTokenUsage(
            promptTokens: metadata.promptTokenCount ?? 0,
            completionTokens: metadata.candidatesTokenCount ?? 0,
            totalTokens: metadata.totalTokenCount ?? 0
        )
    }

    // Helper to create a mutable copy for setting model/vendor after decoding
    func changingModel(to newModel: String?) -> GoogleGenerateContentResponse {
        var copy = self
        copy.model = newModel
        return copy
    }
}

// Structure for parsing individual streaming chunks
// Fields mirror main response but are optional as chunks are partial
struct GoogleStreamedGenerateContentResponse: Codable {
    let candidates: [GoogleCandidate]?
    let usageMetadata: GoogleUsageMetadata? // Usually only in the final chunk
    let promptFeedback: GooglePromptFeedback?
}

// --- Supporting Response Sub-structs ---

struct GoogleCandidate: Codable {
    let content: GoogleContent
    let finishReason: String? // e.g., "STOP", "MAX_TOKENS", "SAFETY"
    let safetyRatings: [GoogleSafetyRating]?
    let citationMetadata: GoogleCitationMetadata?
    let index: Int? // Index of the candidate
}

struct GoogleUsageMetadata: Codable {
    let promptTokenCount: Int?
    let candidatesTokenCount: Int?
    let totalTokenCount: Int?
}

struct GooglePromptFeedback: Codable {
    let blockReason: String?
    let safetyRatings: [GoogleSafetyRating]?
    // blockReasonMessage if needed
}

struct GoogleSafetyRating: Codable {
    let category: String // e.g., "HARM_CATEGORY_HARASSMENT"
    let probability: String // e.g., "NEGLIGIBLE", "LOW", "MEDIUM", "HIGH"
    let blocked: Bool? // If safety blocked this category
}

struct GoogleCitationMetadata: Codable {
    let citationSources: [GoogleCitationSource]?
}

struct GoogleCitationSource: Codable {
    let startIndex: Int?
    let endIndex: Int?
    let uri: String?
    let license: String?
}
