//
//  MLManagerTests.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 5/5/25.
//

import XCTest
import CoreML
import NaturalLanguage
@testable import AuroraCore
@testable import AuroraML

final class MLManagerTests: XCTestCase {
    var manager: MLManager!

    override func setUpWithError() throws {
        manager = MLManager()
    }

    override func tearDown() {
        manager = nil
    }

    func testRegisteredServiceNames() async {
        let mock1 = MockMLService(name: "first")
        let mock2 = MockMLService(name: "second")
        await manager.register(mock1)
        await manager.register(mock2)

        let names = await manager.registeredServiceNames
        XCTAssertTrue(names.contains("first"))
        XCTAssertTrue(names.contains("second"))
        XCTAssertEqual(names.count, 2)
    }

    func testRegisterAndRunInference() async throws {
        let mock = MockMLService(name: "sentiment-test",
                                 response: MLResponse(outputs: ["sentiment": "Positive"], info: nil))
        await manager.register(mock)

        let req = MLRequest(inputs: ["text": "Test"], options: nil)
        let resp = try await manager.run("sentiment-test", request: req)

        XCTAssertEqual(resp.outputs["sentiment"] as? String, "Positive")
    }

    func testServiceLookupError() async {
        do {
            _ = try await manager.run("unknown-service", request: MLRequest(inputs: [:]))
            XCTFail("Expected an error for unknown service")
        } catch {
            // Confirm it's the MLManager “not found” error
            XCTAssertEqual((error as NSError).code, 1)
        }
    }

    func testUnregisterService() async {
        let mock = MockMLService(name: "temp-service")
        await manager.register(mock)
        await manager.unregisterService(withName: "temp-service")

        do {
            _ = try await manager.run("temp-service", request: MLRequest(inputs: [:]))
            XCTFail("Expected error after unregistering")
        } catch {
            XCTAssertEqual((error as NSError).code, 1)
        }
    }

    func testReplaceService() async throws {
        // Register first service
        let firstMock = MockMLService(name: "sentiment-test",
                                      response: MLResponse(outputs: ["sentiment": "Positive"], info: nil))
        await manager.register(firstMock)

        // Replace with second service
        let secondMock = MockMLService(name: "sentiment-test",
                                       response: MLResponse(outputs: ["sentiment": "Negative"], info: nil))
        await manager.register(secondMock)

        let servicesCount = await manager.services.count
        XCTAssertEqual(servicesCount, 1, "Expected only one service after replacement")

        let req = MLRequest(inputs: ["text": "Test"], options: nil)
        let resp = try await manager.run("sentiment-test", request: req)

        XCTAssertEqual(resp.outputs["sentiment"] as? String, "Negative")
    }

    func testActiveServiceDefaultAndRun() async throws {
        let mock = MockMLService(
            name: "sentiment-default",
            response: MLResponse(outputs: ["sentiment": "Default"], info: nil)
        )
        await manager.register(mock)

        // Default active service should be set
        let activeServiceName = await manager.activeServiceName
        XCTAssertEqual(activeServiceName, "sentiment-default")

        // run(request:) uses the active service
        let req = MLRequest(inputs: ["text": "Test"], options: nil)
        let resp = try await manager.run(request: req)
        XCTAssertEqual(resp.outputs["sentiment"] as? String, "Default")
    }

    func testSetActiveService() async throws {
        let first = MockMLService(
            name: "first",
            response: MLResponse(outputs: ["res": "1"], info: nil)
        )
        let second = MockMLService(
            name: "second",
            response: MLResponse(outputs: ["res": "2"], info: nil)
        )
        await manager.register(first)
        await manager.register(second)

        // Initially active is the first registered
        let activeServiceName = await manager.activeServiceName
        XCTAssertEqual(activeServiceName, "first")

        // Switch to second
        try await manager.setActiveService(byName: "second")
        let activeServiceName2 = await manager.activeServiceName
        XCTAssertEqual(activeServiceName2, "second")

        let req = MLRequest(inputs: ["data": "x"], options: nil)
        let resp = try await manager.run(request: req)
        XCTAssertEqual(resp.outputs["res"] as? String, "2")
    }

    func testInferenceErrorPropagates() async {
        let mock = MockMLService(name: "bad-service",
                                 response: MLResponse(outputs: [:]),
                                 shouldThrow: true)
        await manager.register(mock)

        do {
            _ = try await manager.run("bad-service", request: MLRequest(inputs: [:]))
            XCTFail("Expected the mock service to throw")
        } catch {
            XCTAssertEqual((error as NSError).domain, "MockMLService")
        }
    }

    func testFallbackServiceUsedOnPrimaryFailure() async throws {
        let primary = MockMLService(
            name: "primary",
            response: MLResponse(outputs: ["result": "A"], info: nil),
            shouldThrow: true
        )
        let fallback = MockMLService(
            name: "fallback",
            response: MLResponse(outputs: ["result": "B"], info: nil)
        )
        await manager.register(primary)
        await manager.register(fallback)
        await manager.registerFallbackService(fallback)

        let req = MLRequest(inputs: ["x": "y"], options: nil)
        let resp = try await manager.run("primary", request: req)
        XCTAssertEqual(resp.outputs["result"] as? String, "B",
                       "Expected fallback response when primary throws")
    }

    func testFallbackNotCalledWhenPrimarySucceeds() async throws {
        let primary = MockMLService(
            name: "primary",
            response: MLResponse(outputs: ["result": "A"], info: nil)
        )
        let fallback = MockMLService(
            name: "fallback",
            response: MLResponse(outputs: ["result": "B"], info: nil)
        )
        await manager.register(primary)
        await manager.register(fallback)
        await manager.registerFallbackService(fallback)

        let req = MLRequest(inputs: ["x": "y"], options: nil)
        let resp = try await manager.run("primary", request: req)
        XCTAssertEqual(resp.outputs["result"] as? String, "A",
                       "Expected primary response when it does not throw")
    }

    func testErrorWhenPrimaryFailsAndNoFallback() async {
        let primary = MockMLService(
            name: "primary",
            shouldThrow: true
        )
        await manager.register(primary)

        let req = MLRequest(inputs: ["x": "y"], options: nil)
        do {
            _ = try await manager.run("primary", request: req)
            XCTFail("Expected primary error when no fallback is set")
        } catch {
            XCTAssertEqual((error as NSError).domain, "MockMLService",
                           "Expected error from primary service")
        }
    }

    func testUnregisterFallbackService() async throws {
        let primary = MockMLService(
            name: "primary",
            shouldThrow: true
        )
        let fallback = MockMLService(name: "fallback")
        await manager.register(primary)
        await manager.register(fallback)
        await manager.registerFallbackService(fallback)
        await manager.unregisterFallbackService()

        let req = MLRequest(inputs: ["x": "y"], options: nil)
        do {
            _ = try await manager.run("primary", request: req)
            XCTFail("Expected primary error because fallback was cleared")
        } catch {
            XCTAssertEqual((error as NSError).domain, "MockMLService",
                           "Expected error from primary service after fallback removal")
        }
    }

    func testWithTaggingService() async throws {
        // Given
        let service = TaggingService(
            name: "testtagger",
            schemes: [.lemma],
            unit: .word
        )
        await manager.register(service)

        // When
        let req = MLRequest(inputs: ["strings": ["Running dogs"]])
        let resp = try await manager.run("testtagger", request: req)

        // Then
        guard let groups = resp.outputs["tags"] as? [[Tag]],
              let tags = groups.first else {
            XCTFail("Expected 'tags' output from TaggingService")
            return
        }
        XCTAssertTrue(
            tags.contains { $0.token.lowercased() == "running" && $0.label == "run" },
            "Expected lemma 'run' for 'running'"
        )
        XCTAssertTrue(
            tags.contains { $0.token.lowercased() == "dogs" && $0.label == "dog" },
            "Expected lemma 'dog' for 'dogs'"
        )
    }

    func testWithCoreMLTaggingService() async throws {
        // Given
        let url = modelPath(for: "TrivialTextClassifier.mlmodelc")
        guard let model = try? NLModel(contentsOf: url) else {
            XCTFail("Failed to load model from \(url)")
            return
        }
        let service = ClassificationService(
            name: "trivial",
            model: model,
            scheme: "trivial",
            logger: CustomLogger.shared
        )
        await manager.register(service)

        // When
        let req = MLRequest(inputs: ["strings": ["foo", "bar"]])
        let resp = try await manager.run("trivial", request: req)

        // Then
        guard let groups = resp.outputs["tags"] as? [Tag] else {
            XCTFail("Expected 'tags' output from CoreMLTaggingService")
            return
        }
        let flat = groups.compactMap { $0 }
        print("Flat tags: \(flat)")
        XCTAssertTrue(
            flat.contains { $0.token == "foo" && $0.label == "foo" },
            "Expected model to classify 'foo' ➔ 'foo'"
        )
        XCTAssertTrue(
            flat.contains { $0.token == "bar" && $0.label == "bar" },
            "Expected model to classify 'bar' ➔ 'bar'"
        )
    }

    private func modelPath(for filename: String) -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("models")
            .appendingPathComponent(filename)
    }
}
