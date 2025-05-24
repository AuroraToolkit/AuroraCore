//
//  AnthropicService.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import AuroraCore
import Foundation
import os.log

/**
 `AnthropicService` implements the `LLMServiceProtocol` to interact with the Anthropic API.
 It allows for flexible configuration for different models and temperature settings, and now provides
 detailed error handling using `LLMServiceError`.
 */
public class AnthropicService: LLMServiceProtocol {
    /// A logger for recording information and errors within the `AnthropicService`.
    private let logger: CustomLogger?

    /// The name of the service vendor, required by the protocol.
    public let vendor = "Anthropic"

    /// The name of the service instance, which can be customized during initialization
    public var name: String

    /// The base URL for the Anthropic API.
    private let baseURL: String

    /// The maximum context window size (total tokens, input + output) supported by the service, defaults to 200k.
    public var contextWindowSize: Int

    /// The maximum number of tokens allowed for output (completion) in a single request, defaults to 4k.
    public var maxOutputTokens: Int

    /// Specifies the policy to handle input tokens when they exceed the service's input token limit, defaults to `.adjustToServiceLimits`.
    public var inputTokenPolicy: TokenAdjustmentPolicy

    /// Specifies the policy to handle output tokens when they exceed the service's max output token limit, defaults to `adjustToServiceLimits`.
    public var outputTokenPolicy: TokenAdjustmentPolicy

    /// The default system prompt for this service, used to set the behavior or persona of the model.
    public var systemPrompt: String?

    /// The URL session used to send basic requests.
    var urlSession: URLSession

    /**
     Initializes a new `AnthropicService` instance with the given API key and token limit.

     - Parameters:
        -  name: The name of the service instance (default is `"Anthropic"`).
        - baseURL: The base URL for the Anthropic API. Defaults to "https://api.anthropic.com".
        - apiKey: The API key used for authenticating requests to the Anthropic API.
        - contextWindowSize: The size of the context window used by the service. Defaults to 200k.
        - maxOutputTokens: The maximum number of tokens allowed for output in a single request. Defaults to 4096.
        - inputTokenPolicy: The policy to handle input tokens exceeding the service's limit. Defaults to `.adjustToServiceLimits`.
        - outputTokenPolicy: The policy to handle output tokens exceeding the service's limit. Defaults to `.adjustToServiceLimits`.
        - systemPrompt: The default system prompt for this service, used to set the behavior or persona of the model.
        - urlSession: The `URLSession` instance used for network requests. Defaults to a `.default` configuration.
        - logger: An optional logger for recording information and errors within the service.
     */
    public init(name: String = "Anthropic", baseURL: String = "https://api.anthropic.com", apiKey: String?, contextWindowSize: Int = 200_000, maxOutputTokens: Int = 4096, inputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits, outputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits, systemPrompt: String? = nil, urlSession: URLSession = URLSession(configuration: .default), logger: CustomLogger? = nil) {
        self.name = name
        self.baseURL = baseURL
        self.contextWindowSize = contextWindowSize
        self.maxOutputTokens = maxOutputTokens
        self.inputTokenPolicy = inputTokenPolicy
        self.outputTokenPolicy = outputTokenPolicy
        self.systemPrompt = systemPrompt
        self.urlSession = urlSession
        self.logger = logger

        if let apiKey {
            SecureStorage.saveAPIKey(apiKey, for: name)
        }
    }

    actor StreamingState {
        var accumulatedContent = ""
        var inputTokens = 0
        var outputTokens = 0

        func appendContent(_ content: String) {
            accumulatedContent += content
        }

        func updateTokenUsage(input: Int, output: Int) {
            inputTokens += input
            outputTokens += output
        }

        func getUsage() -> AnthropicLLMResponse.Usage {
            return AnthropicLLMResponse.Usage(inputTokens: inputTokens, outputTokens: outputTokens)
        }
    }

    // MARK: - Non-streaming Request

    /**
     Sends a non-streaming request to the Anthropic API and retrieves the response asynchronously.

     - Parameter request: The `LLMRequest` containing the messages and model configuration.

     - Returns: The `LLMResponseProtocol` containing the generated text or an error if the request fails.
     - Throws: `LLMServiceError` if the request encounters an issue (e.g., invalid response, decoding error, etc.).
     */
    public func sendRequest(_ request: LLMRequest) async throws -> LLMResponseProtocol {
        try validateStreamingConfig(request, expectStreaming: false)

        // Use helper function for consistent system prompt handling
        let (systemMessage, userMessages) = prepareAnthropicMessages(from: request, serviceSystemPrompt: systemPrompt)

        // Construct the body with a top-level system parameter
        var body: [String: Any] = [
            "model": request.model ?? "claude-3-5-sonnet-20240620",
            "messages": userMessages,
            "max_tokens": request.maxTokens,
            "temperature": request.temperature,
            "top_p": request.options?.topP ?? 1.0,
        ]

        // Add the system message if available
        if let systemMessage = systemMessage {
            body["system"] = systemMessage
        }

        logger?.debug("AnthropicService [sendRequest] Sending request with keys: \(body.keys)", category: "AnthropicService")

        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])

        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            throw LLMServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version") // Required Anthropic version header

        // Minimize the risk of API key exposure
        guard let apiKey = SecureStorage.getAPIKey(for: name) else {
            throw LLMServiceError.missingAPIKey
        }
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let (data, response) = try await urlSession.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            throw LLMServiceError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        logger?.debug("AnthropicService [sendRequest] Response received from Anthropic", category: "AnthropicService")

        let decodedResponse = try JSONDecoder().decode(AnthropicLLMResponse.self, from: data)
        let finalResponse = decodedResponse.changingVendor(to: vendor)
        return finalResponse
    }

    // MARK: - Streaming Request

    /**
     Sends a request to the Anthropic API and retrieves the response asynchronously.

     - Parameter request: The `LLMRequest` containing the messages and model configuration.
     - Returns: The `LLMResponseProtocol` containing the generated text or an error if the request fails.
     - Throws: `LLMServiceError` if the request encounters an issue (e.g., missing API key, invalid response, etc.).
     */
    public func sendStreamingRequest(_ request: LLMRequest, onPartialResponse: ((String) -> Void)?) async throws -> LLMResponseProtocol {
        try validateStreamingConfig(request, expectStreaming: true)

        // Use helper function for consistent system prompt handling
        let (systemMessage, userMessages) = prepareAnthropicMessages(from: request, serviceSystemPrompt: systemPrompt)

        // Construct the body with a top-level system parameter
        var body: [String: Any] = [
            "model": request.model ?? "claude-3-5-sonnet-20240620",
            "messages": userMessages,
            "max_tokens": request.maxTokens,
            "temperature": request.temperature,
            "top_p": request.options?.topP ?? 1.0,
            "stream": true,
        ]

        // Add the system message if available
        if let systemMessage = systemMessage {
            body["system"] = systemMessage
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])

        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            logger?.debug("Invalid URL: \(baseURL)/v1/messages")
            throw LLMServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version") // Required Anthropic version header

        logger?.debug("AnthropicService [sendStreamingRequest] Sending streaming request with keys: \(body.keys)", category: "AnthropicService")

        // Minimize the risk of API key exposure
        guard let apiKey = SecureStorage.getAPIKey(for: name) else {
            throw LLMServiceError.missingAPIKey
        }
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        return try await withCheckedThrowingContinuation { continuation in
            let streamingDelegate = StreamingDelegate(
                vendor: vendor,
                model: request.model ?? "claude-3-5-sonnet-20240620",
                logger: logger,
                onPartialResponse: onPartialResponse ?? { _ in },
                continuation: continuation
            )
            let session = URLSession(configuration: .default, delegate: streamingDelegate, delegateQueue: nil)
            let task = session.dataTask(with: urlRequest)
            task.resume()
        }
    }

    class StreamingDelegate: NSObject, URLSessionDataDelegate {
        private let vendor: String
        private let model: String
        private let onPartialResponse: (String) -> Void
        private let continuation: CheckedContinuation<LLMResponseProtocol, Error>
        private var accumulatedContent: [AnthropicLLMResponse.Content] = []
        private var inputTokens: Int = 0
        private var outputTokens: Int = 0
        private var isComplete = false
        private let logger: CustomLogger?

        init(vendor: String,
             model: String,
             logger: CustomLogger? = nil,
             onPartialResponse: @escaping (String) -> Void,
             continuation: CheckedContinuation<LLMResponseProtocol, Error>)
        {
            self.vendor = vendor
            self.model = model
            self.logger = logger
            self.onPartialResponse = onPartialResponse
            self.continuation = continuation
            logger?.debug("AnthropicService [StreamingDelegate] initialized for model: \(model)", category: "AnthropicService.StreamingDelegate")
        }

        func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
            guard let eventText = String(data: data, encoding: .utf8) else {
                logger?.debug("AnthropicService Failed to decode data as UTF-8", category: "AnthropicService.StreamingDelegate")
                return
            }

            logger?.debug("AnthropicService [StreamingDelegate] streaming event received", category: "AnthropicService.StreamingDelegate")

            let events = eventText.components(separatedBy: "\n\n")
            for event in events {
                guard !event.isEmpty else { continue }

                if event.contains("event: message_stop") {
                    logger?.debug("AnthropicService [StreamingDelegate] Received message_stop event.", category: "AnthropicService.StreamingDelegate")
                    isComplete = true
                    break
                } else if let dataRange = event.range(of: "data: ") {
                    let jsonString = event[dataRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                    if let jsonData = jsonString.data(using: .utf8) {
                        do {
                            let streamingResponse = try JSONDecoder().decode(AnthropicLLMStreamingResponse.self, from: jsonData)

                            if let delta = streamingResponse.delta, let text = delta.text {
                                let content = AnthropicLLMResponse.Content(type: delta.type, text: text)
                                accumulatedContent.append(content)
                                onPartialResponse(text)

                                logger?.debug("AnthropicService Partial response: \(text)", category: "AnthropicService.StreamingDelegate")
                            }

                            if let usage = streamingResponse.usage {
                                inputTokens = usage.inputTokens ?? 0
                                outputTokens = usage.outputTokens ?? 0
                            }
                        } catch {
                            logger?.error("AnthropicService Failed to decode partial response: \(error.localizedDescription)", category: "AnthropicService.StreamingDelegate")
                        }
                    }
                } else {
                    logger?.debug("AnthropicService [StreamingDelegate] Unhandled event type: \(event)", category: "AnthropicService.StreamingDelegate")
                }
            }

            if isComplete {
                let finalResponse = AnthropicLLMResponse(
                    id: UUID().uuidString, // Replace with actual ID from the API if available
                    type: "response",
                    role: "assistant",
                    vendor: vendor,
                    model: model,
                    content: accumulatedContent,
                    stopReason: "end_turn", // Replace with actual stop reason if available
                    usage: AnthropicLLMResponse.Usage(inputTokens: inputTokens, outputTokens: outputTokens)
                )
                continuation.resume(returning: finalResponse)
            }
        }

        func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                logger?.error("AnthropicService [StreamingDelegate] Task completed with error: \(error.localizedDescription)", category: "AnthropicService.StreamingDelegate")
                continuation.resume(throwing: error)
            } else if !isComplete {
                logger?.debug("AnthropicService [StreamingDelegate] Task completed without receiving a message_stop event.", category: "AnthropicService.StreamingDelegate")
                continuation.resume(throwing: LLMServiceError.custom(message: "Streaming response ended prematurely."))
            }
        }
    }
}
