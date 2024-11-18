//
//  OpenAIService.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation
import os.log

/**
 `OpenAIService` implements the `LLMServiceProtocol` to interact with the OpenAI API.
 This service allows flexible configuration for different models and settings, and now provides
 enhanced error handling using `LLMServiceError`.
 */
public class OpenAIService: LLMServiceProtocol {

    /// A logger for recording information and errors within the `AnthropicService`.
    private let logger = Logger(subsystem: "com.mutantsoup.AuroraCore", category: "OpenAIService")

    /// The name of the service vendor, required by the protocol.
    public let vendor = "OpenAI"

    /// The name of the service instance, which can be customized during initialization
    public var name: String

    /// The base url for the OpenAI API.
    public var baseURL: String

    /// The API key used for authenticating requests to the OpenAI API.
    public var apiKey: String?

    /// OpenAI requires an API key for authentication.
    public let requiresAPIKey = true

    /// The maximum token limit that can be processed by this service.
    public let maxTokenLimit: Int

    /**
     Initializes a new `OpenAIService` instance with the given API key and token limit.

     - Parameters:
     - name: The name of the service instance (default is `"OpenAI"`).
     - baseURL: The base URL for the OpenAI API. Defaults to "https://api.openai.com".
     - apiKey: The API key used for authenticating requests to the OpenAI API.
     - maxTokenLimit: The maximum number of tokens allowed in a request. Defaults to 4096.
     */
    public init(name: String = "OpenAI", baseURL: String = "https://api.openai.com", apiKey: String?, maxTokenLimit: Int = 4096) {
        self.name = name
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.maxTokenLimit = maxTokenLimit
    }

    // MARK: - Non-streaming Request

    /**
     Sends a request to the OpenAI API asynchronously without streaming.

     - Parameters:
     - request: The `LLMRequest` containing the messages and model configuration.
     - Returns: The `LLMResponseProtocol` containing the generated text or an error if the request fails.
     - Throws: `LLMServiceError` if the request encounters an issue (e.g., missing API key, invalid response, etc.).
     */
    public func sendRequest(_ request: LLMRequest) async throws -> LLMResponseProtocol {
        // Ensure streaming is disabled for this method
        guard request.stream == false else {
            throw LLMServiceError.custom(message: "Streaming is not supported in sendRequest(). Use sendStreamingRequest() instead.")
        }

        guard let apiKey = apiKey else {
            throw LLMServiceError.missingAPIKey
        }

        // Setup URL and URLRequest
        guard var components = URLComponents(string: baseURL) else {
            throw LLMServiceError.invalidURL
        }

        components.path = "/v1/chat/completions"
        guard let url = components.url else {
            throw LLMServiceError.invalidURL
        }

        let messagesPayload = request.messages.map { message in
            ["role": message.role.rawValue, "content": message.content]
        }

        let body: [String: Any] = [
            "model": request.model ?? "gpt-4o",
            "messages": messagesPayload,
            "max_tokens": request.maxTokens,
            "temperature": request.temperature,
            "top_p": request.options?.topP ?? 1.0,
            "frequency_penalty": request.options?.frequencyPenalty ?? 0.0,
            "presence_penalty": request.options?.presencePenalty ?? 0.0,
            "stop": request.options?.stopSequences ?? [],
            "stream": request.stream
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        logger.log("OpenAIService \(#function) Sending request: \(body)")

        // Non-streaming response handling
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw LLMServiceError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        if let jsonString = String(data: data, encoding: .utf8) {
            logger.log("OpenAIService \(#function) Received response: \(jsonString)")
        }

        let decodedResponse = try JSONDecoder().decode(OpenAILLMResponse.self, from: data)
        return decodedResponse
    }

    // MARK: - Streaming Request

    /**
     Sends a request to the OpenAI API asynchronously with streaming support.

     - Parameters:
     - request: The `LLMRequest` containing the messages and model configuration.
     - onPartialResponse: A closure that handles partial responses during streaming.
     - Returns: The `LLMResponseProtocol` containing the final text generated by the LLM.
     - Throws: `LLMServiceError` if the request encounters an issue (e.g., missing API key, invalid response, etc.).
     */
    public func sendStreamingRequest(_ request: LLMRequest, onPartialResponse: ((String) -> Void)?) async throws -> LLMResponseProtocol {
        // Ensure streaming is enabled for this method
        guard request.stream else {
            throw LLMServiceError.custom(message: "Streaming is required in sendStreamingRequest(). Set request.stream to true.")
        }

        guard let apiKey = apiKey else {
            throw LLMServiceError.missingAPIKey
        }

        // URL and request setup
        guard var components = URLComponents(string: baseURL) else {
            throw LLMServiceError.invalidURL
        }
        components.path = "/v1/chat/completions"
        guard let url = components.url else {
            throw LLMServiceError.invalidURL
        }

        let messagesPayload = request.messages.map { message in
            ["role": message.role.rawValue, "content": message.content]
        }

        let body: [String: Any] = [
            "model": request.model ?? "gpt-4o",
            "messages": messagesPayload,
            "max_tokens": request.maxTokens,
            "temperature": request.temperature,
            "top_p": request.options?.topP ?? 1.0,
            "frequency_penalty": request.options?.frequencyPenalty ?? 0.0,
            "presence_penalty": request.options?.presencePenalty ?? 0.0,
            "stop": request.options?.stopSequences ?? [],
            "stream": true
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        logger.log("OpenAIService \(#function) Sending streaming request.")

        return try await withCheckedThrowingContinuation { continuation in
            let streamingDelegate = StreamingDelegate(
                model: request.model ?? "gpt-4o",
                onPartialResponse: onPartialResponse ?? { _ in },
                continuation: continuation
            )
            let session = URLSession(configuration: .default, delegate: streamingDelegate, delegateQueue: nil)
            let task = session.dataTask(with: urlRequest)
            task.resume()
        }
    }

    internal class StreamingDelegate: NSObject, URLSessionDataDelegate {
        private let model: String
        private let onPartialResponse: (String) -> Void
        private let continuation: CheckedContinuation<LLMResponseProtocol, Error>
        private var accumulatedContent = ""
        private var finalResponse: LLMResponseProtocol?
        private let logger = Logger(subsystem: "com.mutantsoup.AuroraCore", category: "OpenAIService.StreamingDelegate")

        init(model: String,
             onPartialResponse: @escaping (String) -> Void,
             continuation: CheckedContinuation<LLMResponseProtocol, Error>) {
            self.model = model
            self.onPartialResponse = onPartialResponse
            self.continuation = continuation
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            guard let responseText = String(data: data, encoding: .utf8) else { return }

            logger.log("Response: \(responseText)")

            for line in responseText.split(separator: "\n") {
                if line == "data: [DONE]" {
                    // Finalize the response
                    let usage = OpenAILLMResponse.Usage(prompt_tokens: 0, completion_tokens: 0, total_tokens: 0)
                    let finalResponse = OpenAILLMResponse(
                        choices: [OpenAILLMResponse.Choice(
                            delta: nil,
                            message: OpenAILLMResponse.Choice.Message(role: "assistant", content: accumulatedContent),
                            finish_reason: "stop"
                        )],
                        usage: usage,
                        model: model
                    )
                    continuation.resume(returning: finalResponse)
                    return
                }

                // Remove `data:` prefix and decode JSON
                if line.starts(with: "data:") {
                    let jsonString = line.replacingOccurrences(of: "data: ", with: "")
                    logger.log("JSON string: \(jsonString)")

                    if let jsonData = jsonString.data(using: .utf8) {
                        do {
                            let partialResponse = try JSONDecoder().decode(OpenAILLMResponse.self, from: jsonData)

                            // Append content from `delta`
                            if let partialContent = partialResponse.choices.first?.delta?.content {
                                accumulatedContent += partialContent
                                onPartialResponse(partialContent)
                            }
                        } catch {
                            logger.log("Decoding error: \(error)")
                        }
                    }
                }
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                continuation.resume(throwing: error)
            }
        }
    }
}
