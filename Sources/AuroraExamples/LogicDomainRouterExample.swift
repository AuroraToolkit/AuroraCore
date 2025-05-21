//
//  LogicDomainRouterExample.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 4/25/25.
//

import AuroraCore
import AuroraLLM
import Foundation

// Simple, deterministic linear-congruential generator
// Fine for demos/tests, but not cryptographically secure because its output is predictable.
final class SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    func next() -> UInt64 {
        state = 6_364_136_223_846_793_005 &* state &+ 1
        return state
    }
}

/**
 An example of using the `LogicDomainRouter` to route requests based on various criteria.
 */
struct LogicDomainRouterExample {
    let privacyRouter = LogicDomainRouter(
        name: "Privacy Gate",
        supportedDomains: ["private", "public"],
        rules: [
            .regex(name: "Credit Card",
                   pattern: #"\b(?:\d[ -]*?){13,16}\b"#,
                   domain: "private", priority: 100),
            .regex(name: "US Phone",
                   pattern: #"\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b"#,
                   domain: "private", priority: 100),
            .regex(name: "Email",
                   pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
                   domain: "private",
                   priority: 100),
            .regex(name: "SSN",
                   pattern: #"\b\d{3}-\d{2}-\d{4}\b"#,
                   domain: "private",
                   priority: 100),
        ],
        defaultDomain: "public",
        evaluationStrategy: .highestPriority
    )

    let costRouter = LogicDomainRouter(
        name: "Cost Tier",
        supportedDomains: ["economy", "premium"],
        rules: [
            .tokens(name: "Cheap for short (<40 tokens)",
                    domain: "economy") { $0 < 40 },
        ],
        defaultDomain: "premium",
        evaluationStrategy: .firstMatch
    )

    let latencyRouter = LogicDomainRouter(
        name: "Latency Optimiser (route to a fast QnA model)",
        supportedDomains: ["fastQA", "default"],
        rules: [
            .regex(name: "Ends with question mark",
                   pattern: #"\?$"#,
                   domain: "fastQA"),
        ],
        defaultDomain: "default"
    )

    let langRouter = LogicDomainRouter(
        name: "Language Splitter",
        supportedDomains: ["foreign", "english"],
        rules: [
            .regex(name: "Non-ASCII letter",
                   pattern: #"(?i)[^\p{ASCII}\P{L}]"#, // any Unicode letter outside ASCII range
                   domain: "foreign"),
        ],
        defaultDomain: "english"
    )

    let abRouterRandom = LogicDomainRouter(
        name: "A/B Experiment",
        supportedDomains: ["baseline", "experiment"],
        rules: [.regex(name: "Match all", pattern: #".+"#, domain: "baseline")],
        defaultDomain: "baseline",
        evaluationStrategy: .probabilisticWeights(
            selector: { _ in [("baseline", 0.7), ("experiment", 0.3)] },
            rng: SystemRandomNumberGenerator()
        )
    )

    let abRouterSeeded = LogicDomainRouter(
        name: "A/B Experiment",
        supportedDomains: ["baseline", "experiment"],
        rules: [.regex(name: "Match all", pattern: #".+"#, domain: "baseline")],
        defaultDomain: "baseline",
        evaluationStrategy: .probabilisticWeights(
            selector: { _ in [("baseline", 0.7), ("experiment", 0.3)] },
            rng: SeededGenerator(seed: 123_456_789)
        )
    )

    func execute() async {
        let basePrompts = [
            "How tall is Mount Everest?",
            "Translate 'thank you' to French.",
            "My email is john.doe@example.com",
            "What’s today’s mortgage rate?",
            "score update for the Lakers game?",
            "¿Cuál es la capital de España?",
        ]

        let privacyPrompts = [
            "Contact me at alice@example.com",
            "Here is my SSN: 123-45-6789",
            "My Visa is 4111-1111-1111-1111",
            "Call me on 512-555-1234",
        ]

        let abPrompts = Array(repeating: "Route me", count: 10)

        let costPrompts = basePrompts + [
            String(repeating: "lorem ipsum ", count: 15),
        ]

        let promptClock = incrementalClock(
            start: Calendar.current.date(
                from: DateComponents(
                    calendar: .current,
                    year: 2025, month: 4, day: 25,
                    hour: 0, minute: 0
                ))!,
            interval: 2 * 3600 // 2 hours in seconds
        )

        let routerClock = incrementalClock(
            start: Calendar.current.date(
                from: DateComponents(
                    calendar: .current,
                    year: 2025, month: 4, day: 25,
                    hour: 0, minute: 0
                ))!,
            interval: 2 * 3600 // 2 hours in seconds
        )

        let afterHoursPrompts = basePrompts.map { prompt in
            // grab the next tick of your two-hour clock
            let date = promptClock()
            // format it nicely (or just interpolate the Date)
            let timeString = DateFormatter.localizedString(
                from: date,
                dateStyle: .none,
                timeStyle: .short
            )
            return "\(prompt) at \(timeString)"
        }

        let afterHoursRouter = LogicDomainRouter(
            name: "After-Hours",
            supportedDomains: ["offPeak", "daytime"],
            rules: [
                .hours(name: "Midnight-5 AM",
                       hours: 0 ... 5,
                       domain: "offPeak",
                       clock: routerClock),
            ],
            defaultDomain: "daytime"
        )

        let latencyPrompts = basePrompts + [
            "Really?",
            "Tell me a joke",
        ]

        let langPrompts = basePrompts + [
            "这是什么？",
            "¿Dónde está la biblioteca?",
        ]

        print("Privacy routing (PII detection):")
        await run(router: privacyRouter,
                  prompts: basePrompts + privacyPrompts)

        print("\n\nCost-tier routing (token count):")
        await run(router: costRouter,
                  prompts: costPrompts)

        print("\n\nAfter-hours routing (time of day):")
        await run(router: afterHoursRouter,
                  prompts: afterHoursPrompts)

        print("\n\nLatency routing (question detection):")
        await run(router: latencyRouter,
                  prompts: latencyPrompts + ["Really?"])

        print("\n\nLanguage routing (foreign language detection):")
        await run(router: langRouter,
                  prompts: langPrompts)

        print("\n\nA/B Experiment routing (probabilistic):")
        await run(router: abRouterRandom,
                  prompts: abPrompts)

        print("\n\nA/B Experiment routing (deterministic):")
        await run(router: abRouterSeeded,
                  prompts: abPrompts)
    }

    private func run(router: LogicDomainRouter, prompts: [String]) async {
        for p in prompts {
            let req = LLMRequest(messages: [.init(role: .user, content: p)])
            let domain = try? await router.determineDomain(for: req) ?? "nil"
            print("• \"\(p)\"  →  \(domain!)")
        }
    }

    /// Returns a clock that starts at `startDate` and advances by `interval` each call.
    private func incrementalClock(
        start startDate: Date,
        interval: TimeInterval
    ) -> () -> Date {
        var current = startDate
        return {
            let now = current
            current = current.addingTimeInterval(interval)
            return now
        }
    }
}
