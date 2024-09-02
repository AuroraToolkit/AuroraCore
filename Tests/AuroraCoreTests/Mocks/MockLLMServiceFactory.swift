//
//  MockLLMServiceFactory.swift
//
//
//  Created by Dan Murrell Jr on 9/2/24.
//

import Foundation
@testable import AuroraCore

public class MockLLMServiceFactory: LLMServiceFactory {

    private var mockServices: [String: LLMServiceProtocol] = [:]

    public func registerMockService(_ service: LLMServiceProtocol) {
        mockServices[service.name] = service
    }

    public override func createService(for context: Context) -> LLMServiceProtocol? {
        return mockServices[context.llmServiceName] ?? nil
    }
}
