//
//  DomainRoutingExample.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 11/28/24.
//

import Foundation
import AuroraCore
import AuroraLLM

/**
 An example demonstrating how to use domain-specific routing to LLM services.
 */
struct DomainRoutingExample {
    func execute() async {

        // Initialize the LLMManager
        let manager = LLMManager()

        // Domains we handle
        let sports = ["sports"]
        let movies = ["movies"]
        let books = ["books"]

        // Register a domain router that routes questions to the appropriate service based on the domain
        let router = LLMDomainRouter(
            name: "Domain Router",
            service: OllamaService(),
            supportedDomains: sports + movies + books,
            logger: CustomLogger.shared
        )
        manager.registerDomainRouter(router)

        // Register a mock service that answers questions about the sports domain
        let sportsService = MockLLMService(
            name: "Sports Service",
            vendor: "MockLLM",
            expectedResult: .success(MockLLMResponse(text: "Sports Service Response")))
        manager.registerService(sportsService, withRoutings: [.domain(sports)])

        // Register a mock service that answers questions about the movies domain
        let moviesService = MockLLMService(
            name: "Movies Service",
            vendor: "MockLLM",
            expectedResult: .success(MockLLMResponse(text: "Movies Service Response")))
        manager.registerService(moviesService, withRoutings: [.domain(movies)])

        // Register a mock service that answers questions about the books domain
        let booksService = MockLLMService(
            name: "Books Service",
            vendor: "MockLLM",
            expectedResult: .success(MockLLMResponse(text: "Books Service Response")))
        manager.registerService(booksService, withRoutings: [.domain(books)])

        // Register a general purpose, fallback service
        let generalService = OllamaService(
            name: "General Service",
            baseURL: "http://localhost:11434",
            contextWindowSize: 8192,
            maxOutputTokens: 1024,
            logger: CustomLogger.shared
        )
        manager.registerFallbackService(generalService)

        print("Registered Services Details:")
        print(" - Domain Router: Supported Domains: \(router.supportedDomains)")
        print(" - Sports Service: Context Size: \(sportsService.contextWindowSize), Max Output Tokens: \(sportsService.maxOutputTokens)")
        print(" - Movies Service: Context Size: \(moviesService.contextWindowSize), Max Output Tokens: \(moviesService.maxOutputTokens)")
        print(" - Books Service: Context Size: \(booksService.contextWindowSize), Max Output Tokens: \(booksService.maxOutputTokens)")
        print(" - General Service: Context Size: \(generalService.contextWindowSize), Max Output Tokens: \(generalService.maxOutputTokens)")
        print()

        let sportsquestion = "Who won the rugby championship in 2022?"
        let moviesQuestion = "What won Best Picture in 2021?"
        let booksQuestion = "Who wrote The Great Gatsby?"
        let generalQuestion = "What is the capital of France?"

        let questions = [sportsquestion, moviesQuestion, booksQuestion, generalQuestion]

        for question in questions {
            print("\nSending question to the LLMManager...")
            print("Question: \(question)")

            // Create an LLMRequest for the question
            let request = LLMRequest(messages: [LLMMessage(role: .user, content: question)])
            let response = await manager.routeRequest(request)

            let responseText = response?.text ?? "No response received"
            let responseVendor = response?.vendor ?? "Unknown vendor"
            let responseModel = response?.model ?? "Unknown model"

            print("Response from vendor: \(responseVendor), model: \(responseModel)\n\(responseText)")

            if question == sportsquestion {
                assert(response?.text == "Sports Service Response")
            } else if question == moviesQuestion {
                assert(response?.text == "Movies Service Response")
            } else if question == booksQuestion {
                assert(response?.text == "Books Service Response")
            } else {
                assert(response?.text != nil)
            }
        }
    }
}

fileprivate class MockLLMService: LLMServiceProtocol {
    var name: String
    var vendor: String
    var apiKey: String?
    var requiresAPIKey = false
    var contextWindowSize: Int
    var maxOutputTokens: Int
    var inputTokenPolicy: TokenAdjustmentPolicy
    var outputTokenPolicy: TokenAdjustmentPolicy
    var systemPrompt: String?
    private let expectedResult: Result<LLMResponseProtocol, Error>
    private let streamingExpectedResult: String?

    // Properties to track calls and parameters for verification
    var receivedRequests: [LLMRequest] = []
    var receivedStreamingRequests: [LLMRequest] = []
    var receivedRoutingStrategy: String.TrimmingStrategy?
    var receivedFallbackCount = 0

    init(name: String, vendor: String = "MockLLM", apiKey: String? = nil, requiresAPIKey: Bool = false, contextWindowSize: Int = 8192, maxOutputTokens: Int = 4096, inputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits, outputTokenPolicy: TokenAdjustmentPolicy = .adjustToServiceLimits, systemPrompt: String? = nil, expectedResult: Result<LLMResponseProtocol, Error>, streamingExpectedResult: String? = nil) {
        self.name = name
        self.vendor = vendor
        self.apiKey = apiKey
        self.requiresAPIKey = requiresAPIKey
        self.contextWindowSize = contextWindowSize
        self.maxOutputTokens = maxOutputTokens
        self.inputTokenPolicy = inputTokenPolicy
        self.outputTokenPolicy = outputTokenPolicy
        self.systemPrompt = systemPrompt
        self.expectedResult = expectedResult
        self.streamingExpectedResult = streamingExpectedResult
    }

    /// Non-streaming request handler
    func sendRequest(_ request: LLMRequest) async throws -> LLMResponseProtocol {
        // Track received request for verification in tests
        receivedRequests.append(request)

        // Simulate returning the expected result
        switch expectedResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    /// Streaming request handler
    func sendStreamingRequest(_ request: LLMRequest, onPartialResponse: ((String) -> Void)?) async throws -> LLMResponseProtocol {
        // Track received request for streaming verification in tests
        receivedStreamingRequests.append(request)

        if let streamingExpectedResult = streamingExpectedResult, let onPartialResponse = onPartialResponse {
            // Simulate partial response streaming
            onPartialResponse(streamingExpectedResult)
        }

        // Return the final result after partial response simulation
        switch expectedResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}

fileprivate struct MockLLMResponse: LLMResponseProtocol {

    /// The mock text content returned by the mock LLM.
    public var text: String

    /// The vendor of the model used for generating the response
    public var vendor: String?

    /// The model name for the mock LLM (optional).
    public var model: String?

    /// Token usage data for the mock response.
    public var tokenUsage: LLMTokenUsage?

    /**
     Initializes a `MockLLMResponse` instance.

     - Parameters:
        - text: The mock text content.
        - vendor: The vendor of the mock LLM.
        - model: The model name (optional).
        - tokenUsage: The mock token usage statistics (optional).
     */
    public init(text: String, vendor: String = "Test Vendor", model: String? = "MockLLM", tokenUsage: LLMTokenUsage? = nil) {
        self.text = text
        self.vendor = vendor
        self.model = model
        self.tokenUsage = tokenUsage
    }
}
