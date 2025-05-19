//
//  MockMLService.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/5/25.
//

import Foundation
import AuroraML

public class MockMLService: MLServiceProtocol {
    public var name: String

    let response: MLResponse
    let shouldThrow: Bool

    init(name: String,
         response: MLResponse = MLResponse(outputs: ["result": "ok"], info: nil),
         shouldThrow: Bool = false) {
        self.name = name
        self.response = response
        self.shouldThrow = shouldThrow
    }

    public func run(request: MLRequest) async throws -> MLResponse {
        if shouldThrow {
            throw NSError(domain: "MockMLService", code: 99,
                          userInfo: [NSLocalizedDescriptionKey: "forced error"])
        }
        return response
    }
}
