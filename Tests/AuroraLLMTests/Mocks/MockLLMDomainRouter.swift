//
//  MockLLMDomainRouter.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 12/12/24.
//

import Foundation
@testable import AuroraCore
@testable import AuroraLLM

class MockLLMDomainRouter: LLMDomainRouterProtocol {
    let name: String
    var service: LLMServiceProtocol
    var supportedDomains: [String]
    private let expectedDomain: String?
    private let shouldThrowError: Bool

    init(name: String, service: LLMServiceProtocol, supportedDomains: [String] = [], expectedDomain: String? = nil, shouldThrowError: Bool = false) {
        self.name = name
        self.service = service
        self.supportedDomains = supportedDomains
        self.expectedDomain = expectedDomain
        self.shouldThrowError = shouldThrowError
    }

    func determineDomain(for request: LLMRequest) async throws -> String? {
        if shouldThrowError {
            throw NSError(domain: "MockLLMDomainRouterError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error determining domain"])
        }
        return expectedDomain ?? ""
    }
}
