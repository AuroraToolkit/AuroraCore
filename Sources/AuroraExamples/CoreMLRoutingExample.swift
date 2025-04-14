//
//  CoreMLRoutingExample.swift
//  AuroraExamples
//
//  Created by Dan Murrell Jr on 4/14/25.
//

import Foundation
import AuroraCore
import AuroraLLM

/**
    An example demonstrating how to use CoreMLDomainRouter to classify and route prompts based on local domain prediction.
    This version tests 100 prompts and calculates accuracy.
 */
struct CoreMLRoutingExample {

    func execute() async {
        let modelPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("models")
            .appendingPathComponent("500TextClassifier.mlmodelc")

        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            print("Failed to locate model at \(modelPath.path)")
            return
        }

        let supportedDomains = [
            "sports", "entertainment", "technology", "health", "finance", "general"
        ]

        guard let router = CoreMLDomainRouter(
            name: "ExampleRouter",
            modelURL: modelPath,
            supportedDomains: supportedDomains
        ) else {
            print("Failed to initialize CoreMLDomainRouter.")
            return
        }

        let baseTestCases: [(String, String)] = [
            // sports
            ("Did the Eagles win their last game?", "sports"),
            ("Score update for the Knicks match?", "sports"),
            ("Who hit the most home runs this season?", "sports"),
            ("Are the Celtics in the playoffs?", "sports"),
            ("Which country won the most Olympic medals?", "sports"),
            // entertainment
            ("When is the new Marvel movie releasing?", "entertainment"),
            ("What's the latest gossip about Beyoncé?", "entertainment"),
            ("Is The Bear getting a new season?", "entertainment"),
            ("Which band is headlining Coachella?", "entertainment"),
            ("What was the highest grossing film last year?", "entertainment"),
            // technology
            ("What's the difference between USB-C and Lightning?", "technology"),
            ("How much RAM does the new Pixel have?", "technology"),
            ("Is the Vision Pro headset worth it?", "technology"),
            ("What's the best laptop for machine learning?", "technology"),
            ("Any updates from the Google I/O conference?", "technology"),
            // health
            ("Does magnesium help with sleep?", "health"),
            ("How often should I stretch per day?", "health"),
            ("Is cardio or weights better for weight loss?", "health"),
            ("Can hydration impact cognitive performance?", "health"),
            ("What are early signs of vitamin D deficiency?", "health"),
            // finance
            ("How does a HELOC work?", "finance"),
            ("Is it smart to invest in bonds now?", "finance"),
            ("What’s a good APR for a credit card?", "finance"),
            ("How can I start a Roth IRA?", "finance"),
            ("What's the average retirement savings at 40?", "finance"),
            // general
            ("How many moons does Jupiter have?", "general"),
            ("Who painted the Starry Night?", "general"),
            ("What’s the speed of sound?", "general"),
            ("When was the Declaration of Independence signed?", "general"),
            ("What’s the capital of New Zealand?", "general")
        ]

        // Duplicate and shuffle for 100 prompts
        var testCases: [(String, String)] = []
        for _ in 0..<4 {
            testCases.append(contentsOf: baseTestCases)
        }
        testCases.shuffle()

        var correct = 0
        var total = testCases.count

        print("\nCoreML Routing Test Results:\n")

        for (prompt, expected) in testCases {
            let request = LLMRequest(
                messages: [LLMMessage(role: .user, content: prompt)],
                stream: false
            )

            do {
                let predicted = try await router.determineDomain(for: request)
                let match = (predicted == expected)

                if match {
                    correct += 1
                } else {
                    print("❌ MISMATCH")
                    print("Prompt: \(prompt)")
                    print("Expected: \(expected), Predicted: \(predicted)\n")
                }
            } catch {
                print("⚠️ Error classifying prompt: \(prompt)")
                print("Error: \(error.localizedDescription)\n")
            }
        }

        let accuracy = Double(correct) / Double(total) * 100
        print("✅ Accuracy: \(correct)/\(total) = \(String(format: "%.2f", accuracy))%\n")
    }
}
