//
//  LLMMessageTests.swift
//  AuroraCore
//
//  Created by Dan Murrell Jr on 10/15/24.
//

import Foundation
import Testing
@testable import AuroraCore
@testable import AuroraLLM

struct LLMMessageTests {

    @Test
    func testLLMRoleEquality() async throws {
        #expect(LLMRole.user == LLMRole.user)
        #expect(LLMRole.custom("moderator") == LLMRole.custom("moderator"))
        #expect(LLMRole.user != LLMRole.assistant)
        #expect(LLMRole.custom("moderator") != LLMRole.custom("guest"))
    }

    @Test
    func testLLMMessageEquality() async throws {
        let message1 = LLMMessage(role: .user, content: "Hello")
        let message2 = LLMMessage(role: .user, content: "Hello")
        let message3 = LLMMessage(role: .assistant, content: "Hello")

        #expect(message1 == message2)
        #expect(message1 != message3)
    }

    @Test
    func testLLMRoleCodable() async throws {
        let role = LLMRole.assistant
        let encodedRole = try JSONEncoder().encode(role)
        let decodedRole = try JSONDecoder().decode(LLMRole.self, from: encodedRole)

        #expect(role == decodedRole)

        let customRole = LLMRole.custom("moderator")
        let encodedCustomRole = try JSONEncoder().encode(customRole)
        let decodedCustomRole = try JSONDecoder().decode(LLMRole.self, from: encodedCustomRole)

        #expect(customRole == decodedCustomRole)
    }

    @Test
    func testLLMMessageCodable() async throws {
        let message = LLMMessage(role: .user, content: "Hello world")
        let encodedMessage = try JSONEncoder().encode(message)
        let decodedMessage = try JSONDecoder().decode(LLMMessage.self, from: encodedMessage)

        #expect(message == decodedMessage)

        let customMessage = LLMMessage(role: .custom("moderator"), content: "Follow the rules.")
        let encodedCustomMessage = try JSONEncoder().encode(customMessage)
        let decodedCustomMessage = try JSONDecoder().decode(LLMMessage.self, from: encodedCustomMessage)

        #expect(customMessage == decodedCustomMessage)
    }

    @Test
    func testLLMRoleCustomRawValue() async throws {
        let customRole = LLMRole.custom("analyst")
        #expect(customRole.rawValue == "analyst")

        let predefinedRole = LLMRole.user
        #expect(predefinedRole.rawValue == "user")
    }

    @Test
    func testLLMRoleTrimsWhitespaceAndLowercases() async throws {
        let jsonData1 = "\"   USER  \"".data(using: .utf8)!
        let decodedRole1 = try JSONDecoder().decode(LLMRole.self, from: jsonData1)
        #expect(decodedRole1 == .user)

        let jsonData2 = "\"AsSiStAnt\"".data(using: .utf8)!
        let decodedRole2 = try JSONDecoder().decode(LLMRole.self, from: jsonData2)
        #expect(decodedRole2 == .assistant)

        let jsonData3 = "\"   CustomRole  \"".data(using: .utf8)!
        let decodedRole3 = try JSONDecoder().decode(LLMRole.self, from: jsonData3)
        #expect(decodedRole3 == .custom("customrole"))
    }
}
