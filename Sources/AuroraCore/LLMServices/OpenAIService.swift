//
//  OpenAIService.swift
//  Aurora
//
//  Created by Dan Murrell Jr on 9/1/24.
//

import Foundation

public class OpenAIService: LLMServiceProtocol {
    public var name: String = "OpenAI"
    public var apiKey: String?
    public var maxTokenLimit: Int = 4096 // Example token limit, adjust based on the actual OpenAI model

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func sendRequest(_ request: LLMRequest) async throws -> LLMResponse {
        guard let apiKey = apiKey, let url = URL(string: "https://api.openai.com/v1/completions") else {
            throw NSError(domain: "OpenAIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL or missing API key"])
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": request.model ?? "gpt-4o",
            "prompt": request.prompt,
            "max_tokens": request.maxTokens
        ]

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

        if let text = json?["choices"] as? [[String: Any]], let firstText = text.first?["text"] as? String {
            return LLMResponse(text: firstText)
        } else {
            throw NSError(domain: "OpenAIService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response from OpenAI API"])
        }
    }

    public func sendRequest(_ request: LLMRequest, completion: @escaping (Result<LLMResponse, Error>) -> Void) {
        Task {
            do {
                let response = try await sendRequest(request)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
