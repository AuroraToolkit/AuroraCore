//
//  GoogleService.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 4/3/25.
//

import AuroraCore
import Foundation
import os.log

/**
 `GoogleService` implements the `LLMServiceProtocol` to interact with the Google Generative AI API (Gemini).
 It allows for flexible configuration for different models and temperature settings, handles API key securely,
 and provides error handling using `LLMServiceError`.
 */
public class GoogleService: LLMServiceProtocol {
    /// A logger for recording information and errors within the `GoogleService`.
    private let logger: CustomLogger?

    /// The name of the service vendor, required by the protocol.
    public let vendor = "Google"

    /// The name of the service instance, which can be customized during initialization.
    public var name: String

    /// The base URL for the Google Generative AI API.
    public var baseURL: String

    /// The maximum context window size (total tokens, input + output) supported by the service instance.
    public var contextWindowSize: Int

    /// The maximum number of tokens allowed for output (completion) by the specific model/service configuration.
    public var maxOutputTokens: Int

    /// Specifies the policy to handle input tokens when they exceed the service's input token limit.
    public var inputTokenPolicy: TokenAdjustmentPolicy

    /// Specifies the policy to handle output tokens when they exceed the service's max output token limit.
    public var outputTokenPolicy: TokenAdjustmentPolicy

    /// The default system prompt for this service instance, used to set the behavior or persona of the model if not overridden in the request.
    public var systemPrompt: String?

    /// The URL session used to send network requests.
    var urlSession: URLSession

    // API key is retrieved from SecureStorage when needed

    /**
     Initializes a new `GoogleService` instance with the given configuration.

     - Parameters:
        - name: The name for this specific service instance (default is `"Google"`). Used for retrieving credentials.
        - baseURL: The base URL for the Google Generative AI API. Defaults to `"https://generativelanguage.googleapis.com"`.
        - apiKey: The API key used for authenticating requests. This key will be stored securely using `SecureStorage`.
        - contextWindowSize: The context window size supported by the model being used. Defaults to `1,048,576` (e.g., Gemini 1.5 Pro).
        - maxOutputTokens: The maximum number of tokens the model can generate in a single response. Defaults to `8192` (e.g., Gemini 1.5 Pro).
        - inputTokenPolicy: The policy for handling requests exceeding the input token limit. Defaults to `.adjustToServiceLimits`.
        - outputTokenPolicy: The policy for handling requests exceeding the maximum output token limit. Defaults to `.adjustToServiceLimits`.
        - systemPrompt: An optional default system prompt to guide the model's behavior for this service instance.
        - urlSession: The `URLSession` instance for network requests. Defaults to a standard configuration.
        - logger: An optional logger for recording information and errors. Defaults to `nil`.
     */
    public init(
        name: String = "Google",
        baseURL: String = "https://generativelanguage.googleapis.com",
        apiKey: String?, // API Key provided on initialization
        contextWindowSize: Int = 1_048_576, // Example: Gemini 1.5 Pro context window
        maxOutputTokens: Int = 8192, // Example: Gemini 1.5 Pro max output tokens
        inputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits,
        outputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits,
        systemPrompt: String? = nil,
        urlSession: URLSession = URLSession(configuration: .default),
        logger: CustomLogger? = nil
    ) {
        self.name = name
        self.baseURL = baseURL
        self.contextWindowSize = contextWindowSize
        self.maxOutputTokens = maxOutputTokens // Store the service's max output capability
        self.inputTokenPolicy = inputTokenPolicy
        self.outputTokenPolicy = outputTokenPolicy
        self.systemPrompt = systemPrompt
        self.urlSession = urlSession
        self.logger = logger

        // Save the API key securely, associated with this service's name
        if let apiKey = apiKey {
            SecureStorage.saveAPIKey(apiKey, for: self.name) // Use the instance name
        } else {
            // Use .info instead of .warning
            logger?.info("GoogleService initialized without an API key for instance '\(name)'. Key must exist in SecureStorage.", category: "GoogleService")
        }
    }

    // MARK: - LLMServiceProtocol Methods

    /**
     Sends a non-streaming request to the Google Generative AI API and retrieves the response asynchronously.

     - Parameter request: The `LLMRequest` containing the messages and model configuration. Ensure `request.stream` is `false`.
     - Returns: An `LLMResponseProtocol` containing the generated text and other metadata.
     - Throws: `LLMServiceError` if the API key is missing, the URL is invalid, the request fails, the response is invalid (non-2xx status), or decoding fails. Also throws errors during request mapping or network issues.
     */
    public func sendRequest(_ request: LLMRequest) async throws -> LLMResponseProtocol {
        try validateStreamingConfig(request, expectStreaming: false)

        // Retrieve API Key securely before making the request
        guard let apiKey = SecureStorage.getAPIKey(for: name) else { // Use instance name
            logger?.error("GoogleService [sendRequest] Missing API Key for service name: \(name)", category: "GoogleService")
            throw LLMServiceError.missingAPIKey
        }

        let modelName = request.model ?? "gemini-2.0-flash" // Use request model or default

        let googleRequest: GoogleGenerateContentRequest
        do {
            googleRequest = try mapToGoogleRequest(request, serviceSystemPrompt: systemPrompt)
        } catch {
            logger?.error("GoogleService [sendRequest] Failed to map request: \(error)", category: "GoogleService")
            throw LLMServiceError.custom(message: "Failed to create Google request structure: \(error.localizedDescription)")
        }

        guard let url = URL(string: "\(baseURL)/v1beta/models/\(modelName):generateContent") else {
            logger?.error("GoogleService [sendRequest] Invalid URL generated.", category: "GoogleService")
            throw LLMServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key") // Google specific header

        do {
            urlRequest.httpBody = try JSONEncoder().encode(googleRequest)
            logger?.debug("GoogleService [sendRequest] Sending request to \(url.absoluteString)", category: "GoogleService")

            let (data, response) = try await urlSession.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMServiceError.invalidResponse(statusCode: -1) // Indicate non-HTTP response
            }

            logger?.debug("GoogleService [sendRequest] Response status: \(httpResponse.statusCode)", category: "GoogleService")

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Non-UTF8 error body"
                logger?.error("GoogleService [sendRequest] Error response (\(httpResponse.statusCode)): \(errorBody)", category: "GoogleService")
                // Consider decoding Google's specific error JSON structure if available
                throw LLMServiceError.invalidResponse(statusCode: httpResponse.statusCode)
            }

            // Decode the successful response
            let decodedResponse = try JSONDecoder().decode(GoogleGenerateContentResponse.self, from: data)
            // Inject model name and vendor into the response struct
            let finalResponse = decodedResponse
                .changingVendor(to: vendor) // Use the extension method
                .changingModel(to: modelName) // Use the helper method defined in GoogleLLMResponse.swift

            logger?.debug("GoogleService [sendRequest] Response decoded successfully.", category: "GoogleService")
            return finalResponse

        } catch let error as EncodingError {
            logger?.error("GoogleService [sendRequest] Encoding Error: \(error)", category: "GoogleService")
            throw LLMServiceError.custom(message: "Failed to encode request: \(error.localizedDescription)")
        } catch let error as DecodingError {
            // Attempt to get body data again for logging, might fail if network error occurred before response
            let bodyText = String(data: (try? await urlSession.data(for: urlRequest).0) ?? Data(), encoding: .utf8) ?? "N/A"
            logger?.error("GoogleService [sendRequest] Decoding Error: \(error). Body: \(bodyText)", category: "GoogleService")
            throw LLMServiceError.decodingError
        } catch let error as LLMServiceError {
            throw error // Rethrow known service errors
        } catch {
            logger?.error("GoogleService [sendRequest] Network or other error: \(error)", category: "GoogleService")
            throw LLMServiceError.custom(message: "Network or unexpected error: \(error.localizedDescription)") // Wrap unexpected errors
        }
    }

    /**
     Sends a streaming request to the Google Generative AI API and receives the response asynchronously.

     - Parameters:
        - request: The `LLMRequest` containing the messages and model configuration. Ensure `request.stream` is `true`.
        - onPartialResponse: An optional closure that receives chunks of the generated text as they arrive.
     - Returns: An `LLMResponseProtocol` containing the final aggregated text and other metadata once the stream is complete.
     - Throws: `LLMServiceError` if the API key is missing, the URL is invalid, the request fails, the response is invalid, decoding fails, or the stream terminates unexpectedly. Also throws errors during request mapping or network issues.
     */
    public func sendStreamingRequest(_ request: LLMRequest, onPartialResponse: ((String) -> Void)?) async throws -> LLMResponseProtocol {
        guard request.stream else {
            throw LLMServiceError.custom(message: "Streaming flag must be true in sendStreamingRequest().")
        }

        guard let apiKey = SecureStorage.getAPIKey(for: name) else { // Use instance name
            logger?.error("GoogleService [sendStreamingRequest] Missing API Key for service name: \(name)", category: "GoogleService")
            throw LLMServiceError.missingAPIKey
        }

        let modelName = request.model ?? "gemini-2.0-flash"

        let googleRequest: GoogleGenerateContentRequest
        do {
            googleRequest = try mapToGoogleRequest(request, serviceSystemPrompt: systemPrompt)
        } catch {
            logger?.error("GoogleService [sendStreamingRequest] Failed to map request: \(error)", category: "GoogleService")
            throw LLMServiceError.custom(message: "Failed to create Google request structure: \(error.localizedDescription)")
        }

        guard let url = URL(string: "\(baseURL)/v1beta/models/\(modelName):streamGenerateContent") else {
            logger?.error("GoogleService [sendStreamingRequest] Invalid URL generated.", category: "GoogleService")
            throw LLMServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(googleRequest)
            logger?.debug("GoogleService [sendStreamingRequest] Sending request to \(url.absoluteString)", category: "GoogleService")

            // Use withCheckedThrowingContinuation with a custom delegate
            return try await withCheckedThrowingContinuation { continuation in
                let streamingDelegate = StreamingDelegate(
                    model: modelName,
                    vendor: self.vendor,
                    logger: logger,
                    onPartialResponse: onPartialResponse ?? { _ in }, // Provide default empty closure
                    continuation: continuation
                )
                // Create a new session for each streaming request to use the delegate
                let session = URLSession(configuration: .default, delegate: streamingDelegate, delegateQueue: nil)
                let task = session.dataTask(with: urlRequest)
                task.resume()
            }
        } catch let error as EncodingError {
            logger?.error("GoogleService [sendStreamingRequest] Encoding Error: \(error)", category: "GoogleService")
            throw LLMServiceError.custom(message: "Failed to encode streaming request: \(error.localizedDescription)")
        } catch {
            logger?.error("GoogleService [sendStreamingRequest] Error initiating stream: \(error)", category: "GoogleService")
            throw error // Rethrow other potential errors
        }
    }

    // MARK: - Private Helper Methods

    // Maps the internal LLMRequest to the Google API specific request structure.
    private func mapToGoogleRequest(_ request: LLMRequest, serviceSystemPrompt: String?) throws -> GoogleGenerateContentRequest {
        var googleContents: [GoogleContent] = []
        
        // Use helper function for consistent system prompt resolution
        let effectiveSystemPrompt = resolveSystemPrompt(from: request, serviceSystemPrompt: serviceSystemPrompt)
        
        // Process non-system messages
        for message in request.messages {
            let role: String
            switch message.role {
            case .user: role = "user"
            case .assistant: role = "model" // Google uses "model" for assistant role
            case .system:
                // Skip system messages - they're handled by effectiveSystemPrompt
                continue
            case let .custom(customRole):
                logger?.info("GoogleService: Mapping custom role '\(customRole)' to 'user'.", category: "GoogleService")
                role = "user"
            }
            
            guard !role.isEmpty else { continue }
            googleContents.append(GoogleContent(role: role, parts: [GooglePart(text: message.content)]))
        }

        var googleSystemInstruction: GoogleContent?
        if let promptText = effectiveSystemPrompt, !promptText.isEmpty {
            googleSystemInstruction = GoogleContent(role: nil, parts: [GooglePart(text: promptText)])
        }

        // Log the effective system prompt source for debugging
        if effectiveSystemPrompt != nil {
            if request.systemPrompt != nil {
                logger?.debug("GoogleService: Using request.systemPrompt override", category: "GoogleService")
            } else {
                logger?.debug("GoogleService: Using service default systemPrompt", category: "GoogleService")
            }
        }

        // Apply output token policy here before setting maxOutputTokens in config
        var effectiveMaxOutput = request.maxTokens
        switch outputTokenPolicy {
        case .adjustToServiceLimits:
            effectiveMaxOutput = min(request.maxTokens, maxOutputTokens) // Cap at service limit
        case .strictRequestLimits:
            guard request.maxTokens <= maxOutputTokens else {
                logger?.error("GoogleService: Strict output token limit failed. Request maxTokens (\(request.maxTokens)) > Service maxOutputTokens (\(maxOutputTokens))", category: "GoogleService")
                throw LLMServiceError.custom(message: "Requested maxTokens (\(request.maxTokens)) exceeds service limit (\(maxOutputTokens)) with strict policy.")
            }
            // Use request.maxTokens as it's within limits
        }

        let generationConfig = GoogleGenerationConfig(
            temperature: request.temperature,
            topP: request.options?.topP,
            maxOutputTokens: effectiveMaxOutput, // Use adjusted value
            stopSequences: request.options?.stopSequences
        )

        // Note: Input token policy (trimming) should be handled by LLMManager *before* calling sendRequest
        // This service assumes the input request fits within the allowed input limits based on the policy.

        return GoogleGenerateContentRequest(
            contents: googleContents,
            systemInstruction: googleSystemInstruction,
            generationConfig: generationConfig,
            safetySettings: nil
        )
    }

    // MARK: - Streaming Delegate Inner Class

    // Handles the asynchronous data stream for streaming requests.
    private class StreamingDelegate: NSObject, URLSessionDataDelegate {
        private let model: String
        private let vendor: String
        private let onPartialResponse: (String) -> Void
        private let continuation: CheckedContinuation<LLMResponseProtocol, Error>
        private var accumulatedText = ""
        private var finalUsageMetadata: GoogleUsageMetadata?
        private var finalPromptFeedback: GooglePromptFeedback?
        private var isFinished = false // Track if continuation has been resumed
        private var receivedDataBuffer = Data() // Buffer for incomplete JSON objects
        private let logger: CustomLogger?

        init(model: String,
             vendor: String,
             logger: CustomLogger? = nil,
             onPartialResponse: @escaping (String) -> Void,
             continuation: CheckedContinuation<LLMResponseProtocol, Error>)
        {
            self.model = model
            self.vendor = vendor
            self.logger = logger
            self.onPartialResponse = onPartialResponse
            self.continuation = continuation
            logger?.debug("GoogleService [StreamingDelegate] Initialized.", category: "GoogleService.StreamingDelegate")
        }

        // Handles the initial response headers and status code.
        func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            guard !isFinished else {
                completionHandler(.cancel)
                return
            } // Don't process if already finished

            guard let httpResponse = response as? HTTPURLResponse else {
                logger?.error("GoogleService [StreamingDelegate] Received non-HTTP response.", category: "GoogleService.StreamingDelegate")
                safeResume(throwing: LLMServiceError.invalidResponse(statusCode: -1))
                completionHandler(.cancel)
                return
            }

            logger?.debug("GoogleService [StreamingDelegate] Received response status: \(httpResponse.statusCode)", category: "GoogleService.StreamingDelegate")

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                // Allow receiving data for error body, error handled in didComplete or didReceive data
                logger?.info("GoogleService [StreamingDelegate] Received non-2xx status: \(httpResponse.statusCode). Allowing data for error body.", category: "GoogleService.StreamingDelegate")
                completionHandler(.allow)
                return
            }

            completionHandler(.allow) // Proceed with receiving data for 2xx responses
        }

        // Handles incoming data chunks during the streaming process.
        func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
            guard !isFinished else { return } // Don't process if already finished
            receivedDataBuffer.append(data) // Add new data to the buffer

            // Attempt to process complete JSON objects from the buffer
            processBuffer()
        }

        // Processes the data buffer, attempting to parse complete JSON chunks.
        private func processBuffer() {
            while !receivedDataBuffer.isEmpty {
                // Find the next potential JSON object (simple boundary check)
                guard let firstBrace = receivedDataBuffer.firstIndex(of: UInt8(ascii: "{")),
                      let lastBrace = receivedDataBuffer.lastIndex(of: UInt8(ascii: "}"))
                else {
                    // No complete object structure found in buffer yet, wait for more data
                    logger?.debug("GoogleService [StreamingDelegate] Buffer does not contain complete {} structure yet.", category: "GoogleService.StreamingDelegate")
                    break
                }

                // Check if the last brace comes after the first brace
                guard lastBrace >= firstBrace else {
                    logger?.debug("GoogleService [StreamingDelegate] Found braces out of order, waiting for more data.", category: "GoogleService.StreamingDelegate")
                    break // Wait for more data if braces seem out of order
                }

                let potentialJsonData = receivedDataBuffer[firstBrace ... lastBrace]

                // Trim leading/trailing whitespace/newlines just in case (simple filter)
                let trimmedData = potentialJsonData.filter { $0 >= 32 } // Filter out control chars roughly

                // Ensure data is not empty after filtering
                guard !trimmedData.isEmpty else {
                    // Remove the range that resulted in empty data (likely just whitespace/control chars)
                    receivedDataBuffer.removeSubrange(firstBrace ... lastBrace)
                    continue // Try finding the next object
                }

                do {
                    let chunk = try JSONDecoder().decode(GoogleStreamedGenerateContentResponse.self, from: trimmedData)
                    // logger?.debug("GoogleService [StreamingDelegate] Successfully decoded JSON chunk.", category: "GoogleService.StreamingDelegate") // Can be verbose

                    // --- Process the valid chunk ---
                    if let textDelta = chunk.candidates?.first?.content.parts.first?.text {
                        if !textDelta.isEmpty { // Avoid calling back with empty strings if possible
                            accumulatedText += textDelta
                            onPartialResponse(textDelta)
                            // logger?.debug("GoogleService [StreamingDelegate] Received delta: \(textDelta.prefix(50))...", category: "GoogleService.StreamingDelegate")
                        }
                    }
                    if let metadata = chunk.usageMetadata {
                        finalUsageMetadata = metadata
                        logger?.debug("GoogleService [StreamingDelegate] Received usage metadata.", category: "GoogleService.StreamingDelegate")
                    }
                    if let feedback = chunk.promptFeedback {
                        finalPromptFeedback = feedback
                        if let reason = feedback.blockReason {
                            logger?.info("GoogleService [StreamingDelegate] Prompt blocked. Reason: \(reason)", category: "GoogleService.StreamingDelegate")
                        }
                    }
                    if chunk.candidates?.first?.finishReason != nil {
                        logger?.debug("GoogleService [StreamingDelegate] Finish reason received: \(chunk.candidates?.first?.finishReason ?? "N/A")", category: "GoogleService.StreamingDelegate")
                    }
                    // --- End Processing ---

                    // Remove the processed data (including the closing brace) from the buffer
                    receivedDataBuffer.removeSubrange(firstBrace ... lastBrace)
                    // Also remove any leading characters before the first brace we processed
                    if firstBrace > receivedDataBuffer.startIndex {
                        receivedDataBuffer.removeSubrange(receivedDataBuffer.startIndex ..< firstBrace)
                    }

                } catch {
                    // Decoding failed. If buffer seems to only contain this failed chunk, maybe discard it? Risky.
                    // Let's assume incomplete and wait for more data / finalization.
                    logger?.debug("GoogleService [StreamingDelegate] Failed to decode potential JSON chunk. Error: \(error). Waiting for more data or task completion.", category: "GoogleService.StreamingDelegate")
                    break // Break loop and wait for more data or task completion
                }
            } // End while loop
        }

        // Handles the completion of the URLSession task, either successfully or with an error.
        func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            guard !isFinished else { return } // Prevent double resumption

            if let error = error {
                logger?.error("GoogleService [StreamingDelegate] Task completed with error: \(error.localizedDescription)", category: "GoogleService.StreamingDelegate")
                safeResume(throwing: LLMServiceError.custom(message: "URLSession task failed: \(error.localizedDescription)"))
                return
            }

            // Process any remaining data in the buffer one last time
            processBuffer()
            if !receivedDataBuffer.isEmpty {
                logger?.info("GoogleService [StreamingDelegate] Task completed, but data buffer still contains unprocessed data: \(String(data: receivedDataBuffer, encoding: .utf8) ?? "Non-UTF8 data")", category: "GoogleService.StreamingDelegate")
                // This might indicate an incomplete final chunk or non-JSON error message
            }

            // Check HTTP status code on completion
            guard let httpResponse = task.response as? HTTPURLResponse else {
                logger?.error("GoogleService [StreamingDelegate] Task completed without a valid HTTP response.", category: "GoogleService.StreamingDelegate")
                safeResume(throwing: LLMServiceError.invalidResponse(statusCode: -1))
                return
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                logger?.error("GoogleService [StreamingDelegate] Task completed with non-2xx status: \(httpResponse.statusCode).", category: "GoogleService.StreamingDelegate")
                let errorBody = String(data: receivedDataBuffer, encoding: .utf8) ?? "Unknown error body" // Try reading error from buffer
                logger?.error("GoogleService [StreamingDelegate] Error body on completion: \(errorBody)", category: "GoogleService.StreamingDelegate")
                safeResume(throwing: LLMServiceError.invalidResponse(statusCode: httpResponse.statusCode))
                return
            }

            // If task completed successfully without error and status was 2xx, finalize the response
            logger?.debug("GoogleService [StreamingDelegate] Task completed successfully. Finalizing response.", category: "GoogleService.StreamingDelegate")

            // Construct the final response object
            let finalCandidate = GoogleCandidate(
                content: GoogleContent(role: "model", parts: [GooglePart(text: accumulatedText)]),
                finishReason: "STOP", // Assume normal completion if no error/specific reason received
                safetyRatings: finalPromptFeedback?.safetyRatings, // Use feedback if available
                citationMetadata: nil, // Add if parsed
                index: 0
            )

            let finalResponse = GoogleGenerateContentResponse(
                candidates: [finalCandidate],
                usageMetadata: finalUsageMetadata,
                promptFeedback: finalPromptFeedback
            )
            .changingVendor(to: vendor) // Apply extensions to set final details
            .changingModel(to: model)

            safeResume(returning: finalResponse)
        }

        // Safely resumes the continuation, ensuring it only happens once.
        private func safeResume(returning response: LLMResponseProtocol) {
            guard !isFinished else {
                // logger?.debug("GoogleService [StreamingDelegate] Attempted to resume continuation after already finished (returning).", category: "GoogleService.StreamingDelegate")
                return
            }
            isFinished = true
            continuation.resume(returning: response)
        }

        // Safely resumes the continuation with an error, ensuring it only happens once.
        private func safeResume(throwing error: Error) {
            guard !isFinished else {
                // logger?.debug("GoogleService [StreamingDelegate] Attempted to resume continuation after already finished (throwing).", category: "GoogleService.StreamingDelegate")
                return
            }
            isFinished = true
            continuation.resume(throwing: error)
        }
    }
}

// Keep the extension needed for the service implementation
extension GoogleGenerateContentResponse {
    /// Creates a mutable copy with the vendor property set.
    func changingVendor(to newVendor: String?) -> Self {
        var copy = self
        copy.vendor = newVendor
        return copy
    }
}
