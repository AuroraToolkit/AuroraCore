//
//  OpenAIService.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

/**
 `OpenAIService` implements the `LLMServiceProtocol` to interact with the OpenAI API.
 This service allows flexible configuration for different models and settings, and now provides
 enhanced error handling using `LLMServiceError`.
 */
public class OpenAIService: LLMServiceProtocol {

    /// The name of the service, required by the protocol.
    public let name = "OpenAI"

    /// The base url for the OpenAI API.
    public var baseURL: String

    /// The API key used for authenticating requests to the OpenAI API.
    public var apiKey: String?

    /// The maximum token limit that can be processed by this service.
    public let maxTokenLimit: Int

    /**
     Initializes a new `OpenAIService` instance with the given API key and token limit.

     - Parameters:
        - baseURL: The base URL for the OpenAI API. Defaults to "https://api.openai.com".
        - apiKey: The API key used for authenticating requests to the OpenAI API.
        - maxTokenLimit: The maximum number of tokens allowed in a request. Defaults to 4096.
     */
    public init(baseURL: String = "https://api.openai.com", apiKey: String?, maxTokenLimit: Int = 4096) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.maxTokenLimit = maxTokenLimit
    }

    // Define a StreamingState actor to manage streaming safely
    private actor StreamingState {
        var accumulatedContent = ""
        var choices = [OpenAILLMResponse.Choice]()
        var promptTokens = 0
        var completionTokens = 0

        func appendContent(_ content: String) {
            accumulatedContent += content
        }

        func addChoice(_ content: String) {
            let message = OpenAILLMResponse.Choice.Message(role: "assistant", content: content)
            let choice = OpenAILLMResponse.Choice(message: message)
            choices.append(choice)
        }

        func updateTokenUsage(prompt: Int, completion: Int) {
            promptTokens += prompt
            completionTokens += completion
        }

        func getUsage() -> OpenAILLMResponse.Usage {
            return OpenAILLMResponse.Usage(
                prompt_tokens: promptTokens,
                completion_tokens: completionTokens,
                total_tokens: promptTokens + completionTokens
            )
        }
    }

    /**
     Sends a request to the OpenAI API asynchronously without streaming.

     - Parameters:
        - request: The `LLMRequest` containing the messages and model configuration.
     - Returns: The `LLMResponseProtocol` containing the generated text or an error if the request fails.
     - Throws: `LLMServiceError` if the request encounters an issue (e.g., missing API key, invalid response, etc.).
     */
    public func sendRequest(_ request: LLMRequest) async throws -> LLMResponseProtocol {
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
            "model": request.model ?? "gpt-4",
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

        // Non-streaming response handling
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw LLMServiceError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let decodedResponse = try JSONDecoder().decode(OpenAILLMResponse.self, from: data)
        return decodedResponse
    }

    /**
     Sends a request to the OpenAI API asynchronously with streaming support.

     - Parameters:
        - request: The `LLMRequest` containing the messages and model configuration.
        - onPartialResponse: A closure that handles partial responses during streaming.
     - Returns: The `LLMResponseProtocol` containing the final text generated by the LLM.
     - Throws: `LLMServiceError` if the request encounters an issue (e.g., missing API key, invalid response, etc.).
     */
    public func sendRequest(_ request: LLMRequest, onPartialResponse: ((String) -> Void)?) async throws -> LLMResponseProtocol {
        // Check if streaming is enabled. If not, redirect to the non-streaming version.
        guard request.stream else {
            return try await sendRequest(request) // Call the non-streaming version
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
            "model": request.model ?? "gpt-4",
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

        // Actor to manage streaming state
        let state = StreamingState()

        // Handle streaming response
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                Task {
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let data = data else {
                        continuation.resume(throwing: LLMServiceError.invalidResponse(statusCode: -1))
                        return
                    }

                    // Process the streaming data asynchronously
                    if let partialContent = String(data: data, encoding: .utf8) {
                        await state.appendContent(partialContent)
                        await state.addChoice(partialContent)
                        onPartialResponse?(partialContent)

                        if let partialUsage = try? JSONDecoder().decode(OpenAILLMResponse.Usage.self, from: data) {
                            await state.updateTokenUsage(prompt: partialUsage.prompt_tokens, completion: partialUsage.completion_tokens)
                        }
                    }

                    // Check for final HTTP response
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        let usage = await state.getUsage()
                        let finalResponse = OpenAILLMResponse(choices: await state.choices, usage: usage, model: request.model)
                        continuation.resume(returning: finalResponse)
                    } else {
                        continuation.resume(throwing: LLMServiceError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1))
                    }
                }
            }
            task.resume()
        }
    }
}
