//
//  SiriStyleDomainRoutingExample.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 4/24/25.
//

import Foundation
import AuroraCore
import AuroraLLM

/// An example demonstrating a Siri-style domain routing scenario.
struct SiriStyleDomainRoutingExample {
    private func modelPath(for filename: String) -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("models")
            .appendingPathComponent(filename)
    }

    private var supportedDomains: [String] {
        ["private", "public", "unsure"]
    }

    private let testCases: [(String, String)]

    init() {
        self.testCases = [
            // private, will route to on-device local LLM
            ("Remind me to call mom at 7", "private"),
            ("Read my last message", "private"),
            ("Call my brother", "private"),
            ("How many calories did I burn today?", "private"),
            ("Open my calendar", "private"),
            ("Schedule a meeting with Jeff", "private"),
            ("What's on my grocery list?", "private"),
            ("Read my heart rate data", "private"),
            ("Turn off my alarm", "private"),
            ("Open my health summary", "private"),
            ("Add a note to my journal", "private"),
            ("Set a timer for 10 minutes", "private"),
            ("Did I take my medication today?", "private"),
            ("How much money do I have in savings?", "private"),
            ("When is my next doctor's appointment?", "private"),
            ("Text Sarah ‘I'm on my way’", "private"),
            ("What’s my screen time today?", "private"),
            ("What's on my calendar next week?", "private"),
            ("Remind me to take out the trash", "private"),
            ("Mute my phone", "private"),
            ("Turn on do not disturb", "private"),
            ("What's my next workout?", "private"),
            ("Who’s my emergency contact?", "private"),
            ("Open the wallet app", "private"),

            // public, will route to off-device LLM
            ("How tall is Mount Everest?", "public"),
            ("Who won the last Super Bowl?", "public"),
            ("Translate 'thank you' to French", "public"),
            ("Define 'ephemeral'", "public"),
            ("What's the latest news?", "public"),
            ("How old is Taylor Swift?", "public"),
            ("Show me nearby coffee shops", "public"),
            ("How do I bake banana bread?", "public"),
            ("What's the capital of Iceland?", "public"),
            ("Tell me about the James Webb Telescope", "public"),
            ("What's the weather like today?", "public"),
            ("Where is the nearest gas station?", "public"),
            ("How many grams in a pound?", "public"),
            ("What’s the population of Cedar Park?", "public"),

            // ambiguous, will route to on-device local LLM
            ("Do you love me?", "unsure"),
            ("Why do we exist?", "unsure"),
            ("What’s my purpose?", "unsure"),
            ("Should I take the job offer?", "unsure"),
            ("What makes me unique?", "unsure"),
            ("How do I become happy?", "unsure"),
            ("Do people like me?", "unsure"),
            ("Will I be successful?", "unsure"),
            ("What do you think about that?", "unsure"),
            ("What do you think of me?", "unsure"),
            ("Play something relaxing", "unsure"),
            ("How should I feel right now?", "unsure")
        ]
    }

    func execute() async {
        guard
            let router = CoreMLDomainRouter(
                name: "PrimaryRouter",
                modelURL: modelPath(for: "SiriStyleTextClassifier.mlmodelc"),
                supportedDomains: supportedDomains
            )
        else {
            print("❌ Failed to load one or more models.")
            return
        }

        var correct = 0
        for (text, expected) in testCases {
            let request = LLMRequest(messages: [.init(role: .user, content: text)])
            let result = (try? await router.determineDomainWithConfidence(for: request)) ?? nil
            let domain = result?.0 ?? "unknown"
            let confidence = result?.1 ?? 0.0

            let match = domain == expected
            print("\(match ? "✅" : "❌") Prompt: \(text)\nExpected: \(expected), Got: \(domain)\n, Confidence: \(confidence)\n")
            if match { correct += 1 }
        }

        print("🎯 Accuracy: \(correct)/\(testCases.count) = \(Double(correct) / Double(testCases.count) * 100)%")
    }
}
