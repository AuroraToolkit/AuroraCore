//
//  LLMLocalService.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 4/12/25.
//

import Foundation
import LLM

// Minimal implementation of LLMResponseProtocol
public struct LocalLLMResponse: LLMResponseProtocol {
    public var vendor: String?
    public var model: String?
    public var tokenUsage: LLMTokenUsage?
    public let text: String
}

public class LLMLocalService: LLMServiceProtocol {
    private let llm: LLM?

    public var vendor: String
    public let isLocal: Bool = true // Indicates this is a local service
    public var name: String
    public var contextWindowSize: Int
    public var maxOutputTokens: Int
    public var inputTokenPolicy: TokenAdjustmentPolicy
    public var outputTokenPolicy: TokenAdjustmentPolicy
    public var systemPrompt: String?
    public var stopSequence: String?

    // MARK: - Initializers

    public init?(
        vendor: String = "LLMLocal",
        name: String = "LLMLocalService",
        from path: String,
        contextWindowSize: Int = 2048,
        maxOutputTokens: Int = 512,
        inputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits,
        outputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits,
        systemPrompt: String? = nil,
        stopSequence: String? = nil
    ) {
        self.vendor = vendor
        self.name = name
        self.contextWindowSize = contextWindowSize
        self.maxOutputTokens = maxOutputTokens
        self.inputTokenPolicy = inputTokenPolicy
        self.outputTokenPolicy = outputTokenPolicy
        self.systemPrompt = systemPrompt
        self.stopSequence = stopSequence

        self.llm = LLM(from: path, stopSequence: stopSequence, maxTokenCount: Int32(contextWindowSize))

        if self.llm == nil {
            return nil
        }
    }

    public convenience init?(
        vendor: String = "LLMLocal",
        name: String = "LLMLocalService",
        from url: URL,
        contextWindowSize: Int = 2048,
        maxOutputTokens: Int = 512,
        inputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits,
        outputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits,
        systemPrompt: String? = nil,
        stopSequence: String? = nil
    ) {
        self.init(vendor: vendor, name: name, from: url.path, contextWindowSize: contextWindowSize, maxOutputTokens: maxOutputTokens, inputTokenPolicy: inputTokenPolicy, outputTokenPolicy: outputTokenPolicy, systemPrompt: systemPrompt, stopSequence: stopSequence)
    }

    public convenience init?(
    vendor: String = "LLMLocal",
    name: String = "LLMLocalService",
    from huggingFaceModel: HuggingFaceModel,
    to url: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
    contextWindowSize: Int = 2048,
    maxOutputTokens: Int = 512,
    inputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits,
    outputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits,
    systemPrompt: String? = nil,
    stopSequence: String? = nil,
    updateProgress: @Sendable @escaping (Double) -> Void = { print(String(format: "downloaded(%.2f%%)", $0 * 100)) }
    ) async throws {
        let url = try await huggingFaceModel.download(to: url, as: name) { progress in
            Task { @MainActor in updateProgress(progress) }
        }

        self.init(vendor: vendor,name: name,from : url,contextWindowSize: contextWindowSize,maxOutputTokens: maxOutputTokens,inputTokenPolicy: inputTokenPolicy,outputTokenPolicy: outputTokenPolicy,systemPrompt: systemPrompt,stopSequence: stopSequence)
    }

    // MARK: - LLMServiceProtocol Methods

    public func sendRequest(_ request: LLMRequest) async throws -> LLMResponseProtocol {
        guard request.messages.count > 0 else {
            throw NSError(domain: "LLMLocalService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No messages in request."])
        }

        let prompt = request.messages.map { $0.role.rawValue + ": " + $0.content }.joined(separator: "\n")
        let output = await llm?.getCompletion(from: prompt)
        return LocalLLMResponse(vendor: vendor, model: name, tokenUsage: nil, text: output ?? "")
    }

    public func sendStreamingRequest(_ request: LLMRequest, onPartialResponse: ((String) -> Void)?) async throws -> LLMResponseProtocol {
        throw NSError(domain: "LLMLocalService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Streaming not supported for local models."])
    }
}
