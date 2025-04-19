import Foundation
import AuroraCore
import AuroraLLM

struct CoreMLRoutingExample {

    private func modelPath(for filename: String) -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("models")
            .appendingPathComponent(filename)
    }

    private var supportedDomains: [String] {
        ["sports", "entertainment", "technology", "health", "finance", "science"]
    }

    private let testCases: [(String, String)]

    init() {
        let base: [(String, String)] = [
            ("Did the Eagles win their last game?", "sports"),
            ("Score update for the Knicks match?", "sports"),
            ("Who hit the most home runs this season?", "sports"),
            ("Are the Celtics in the playoffs?", "sports"),
            ("Which country won the most Olympic medals?", "sports"),
            ("When is the new Marvel movie releasing?", "entertainment"),
            ("What's the latest gossip about Beyoncé?", "entertainment"),
            ("Is The Bear getting a new season?", "entertainment"),
            ("Which band is headlining Coachella?", "entertainment"),
            ("What was the highest grossing film last year?", "entertainment"),
            ("What's the difference between USB-C and Lightning?", "technology"),
            ("How much RAM does the new Pixel have?", "technology"),
            ("Is the Vision Pro headset worth it?", "technology"),
            ("What's the best laptop for machine learning?", "technology"),
            ("Any updates from the Google I/O conference?", "technology"),
            ("Does magnesium help with sleep?", "health"),
            ("How often should I stretch per day?", "health"),
            ("Is cardio or weights better for weight loss?", "health"),
            ("Can hydration impact cognitive performance?", "health"),
            ("What are early signs of vitamin D deficiency?", "health"),
            ("How does a HELOC work?", "finance"),
            ("Is it smart to invest in bonds now?", "finance"),
            ("What’s a good APR for a credit card?", "finance"),
            ("How can I start a Roth IRA?", "finance"),
            ("What's the average retirement savings at 40?", "finance"),
            ("How many moons does Jupiter have?", "science"),
            ("What is photosynthesis and how does it work?", "science"),
            ("What's the current status of fusion energy research?", "science"),
            ("How do vaccines stimulate the immune system?", "science"),
            ("What are gravitational waves and how are they detected?", "science")
        ]
        let fallback: [(String, String)] = [
            ("What are the pros and cons of remote work?", "general"),
            ("How do people typically prepare for a big event?", "general"),
            ("What trends are shaping the future?", "general"),
            ("How do different cultures celebrate New Year?", "general"),
            ("What are some good habits for daily life?", "general")
        ]

        self.testCases = (0..<4).flatMap { _ in base + fallback }.shuffled()
    }

    func execute() async {
        guard
            let router1 = CoreMLDomainRouter(
                name: "PrimaryRouter",
                modelURL: modelPath(for: "PrimaryTextClassifier.mlmodelc"),
                supportedDomains: supportedDomains
            ),
            let router2 = CoreMLDomainRouter(
                name: "SecondaryRouter",
                modelURL: modelPath(for: "SecondaryTextClassifier.mlmodelc"),
                supportedDomains: supportedDomains
            )
        else {
            print("❌ Failed to load one or more models.")
            return
        }

        let conflictLogger = FileConflictLogger(fileName: "DualExampleRouterConflicts.csv")

        let dualRouter = DualDomainRouter(
            name: "DualRouter",
            primary: router1,
            secondary: router2,
            supportedDomains: supportedDomains,
            confidenceThreshold: 0.1,
            fallbackDomain: "general",
            fallbackConfidenceThreshold: 0.35,
            conflictLogger: conflictLogger
        ) { primary, secondary in
            guard let primary else { return "general" }
            return primary
        }

        let (results1, correct1) = await runTest(named: "Primary", router: router1)
        let (results2, correct2) = await runTest(named: "Secondary", router: router2)
        let (results3, correct3) = await runTest(named: "Dual", router: dualRouter)

        compareResults(primary: results1, secondary: results2, dual: results3)

        print("\n📈 Final Accuracy Comparison:")
        print("- Primary:   \(correct1)/\(testCases.count) = \(String(format: "%.2f", Double(correct1) / Double(testCases.count) * 100))%")
        print("- Secondary: \(correct2)/\(testCases.count) = \(String(format: "%.2f", Double(correct2) / Double(testCases.count) * 100))%")
        print("- Dual:      \(correct3)/\(testCases.count) = \(String(format: "%.2f", Double(correct3) / Double(testCases.count) * 100))%")
    }

    private func runTest(
        named name: String,
        router: any LLMDomainRouterProtocol
    ) async -> ([(prompt: String, expected: String, predicted: String?)], Int) {
        print("\n🧪 Testing router: \(name)\n")
        var results: [(String, String, String?)] = []
        var correct = 0

        for (prompt, expected) in testCases {
            let request = LLMRequest(messages: [.init(role: .user, content: prompt)], stream: false)
            do {
                let predicted = try await router.determineDomain(for: request)
                if predicted == expected {
                    correct += 1
                } else {
                    print("❌ [\(name)] Prompt: \(prompt)\nExpected: \(expected), Got: \(predicted ?? "nil")\n")
                }
                results.append((prompt, expected, predicted))
            } catch {
                print("⚠️ [\(name)] Error: \(error.localizedDescription)")
                results.append((prompt, expected, nil))
            }
        }

        let accuracy = Double(correct) / Double(testCases.count) * 100
        print("✅ \(name) Accuracy: \(correct)/\(testCases.count) = \(String(format: "%.2f", accuracy))%\n")
        return (results, correct)
    }

    private func compareResults(
        primary: [(String, String, String?)],
        secondary: [(String, String, String?)],
        dual: [(String, String, String?)]
    ) {
        print("📊 Comparison Summary:\n")
        for i in 0..<testCases.count {
            let prompt = testCases[i].0
            let expected = testCases[i].1
            let p = primary[i].2 ?? "nil"
            let s = secondary[i].2 ?? "nil"
            let d = dual[i].2 ?? "nil"

            if p != s || p != d || s != d {
                print("🔀 Prompt: \(prompt)\nExpected: \(expected)\nPrimary: \(p), Secondary: \(s), Dual: \(d)\n")
            }
        }
    }
}
