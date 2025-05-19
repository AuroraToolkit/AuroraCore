//
//  MockLLMServiceFactory.swift
//
//
//  Created by Dan Murrell Jr on 9/2/24.
//

import Foundation
@testable import AuroraCore
@testable import AuroraLLM

public class MockLLMServiceFactory: LLMServiceFactory {

    private var mockServices: [String: LLMServiceProtocol] = [:]

    public func registerMockService(_ service: LLMServiceProtocol) {
        mockServices[service.vendor] = service
    }

    public override func createService(for context: Context) -> LLMServiceProtocol? {
        return mockServices[context.llmServiceVendor]
    }
}
