//
//  LogicDomainRouter.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 4/25/25.
//

import AuroraCore
import Foundation

// MARK: - Routing Logic Rule

/**
 A single deterministic rule that can claim an `LLMRequest`
 and map it to a domain.
 */
public struct LogicRule {
    /// Human-readable identifier for logs/metrics.
    public let name: String

    /// The domain returned when the predicate fires.
    public let domain: String

    /// Priority weight (higher wins) – used by `.highestPriority`.
    public let priority: Int

    /// Pure function that inspects the request and returns `true`
    /// when this rule should claim it.
    public let predicate: (LLMRequest) -> Bool

    public init(name: String,
                domain: String,
                priority: Int = 0,
                predicate: @escaping (LLMRequest) -> Bool)
    {
        self.name = name
        self.domain = domain.lowercased()
        self.priority = priority
        self.predicate = predicate
    }
}

// MARK: - Evaluation Strategy

/**
 Determines how the router chooses a domain when evaluating rules.

 * `.firstMatch` – stop at the first rule that matches (fast).
 * `.highestPriority` – evaluate all rules, pick the highest `priority`.
 * `.topKThenResolve` – gather the first *k* matches, pass them to a resolver.
 * `.probabilisticWeights` – resolver returns `(domain, weight)` pairs,
   a weighted random draw selects the domain.
 * `.custom` – caller receives every match array and decides.
 */
public enum EvaluationStrategy {
    case firstMatch
    case highestPriority
    case topKThenResolve(k: Int,
                         resolver: (_ matches: [LogicRule]) -> String?)
    case probabilisticWeights(
        selector: (_ matches: [LogicRule]) -> [(domain: String, weight: Double)],
        rng: RandomNumberGenerator = SystemRandomNumberGenerator()
    )
    case custom((_ matches: [LogicRule]) -> String?)
}

// MARK: - Logic-Based Router

/**
 A purely deterministic router that applies an ordered set
 of `LogicRule`s to an `LLMRequest`.

 Example usage:
 ```swift
 let router = LogicDomainRouter(
     name: "Deterministic",
     supportedDomains: ["sports","finance","private","general"],
     rules: [
         .regex(name: "Sports",
                pattern: #"\b(score|match|nba|nfl)\b"#,
                domain: "sports"),
         .regex(name: "Finance",
                pattern: #"\b(loan|apr|mortgage)\b"#,
                domain: "finance"),
         .regex(name: "PII (email)",
                pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
                domain: "private",
                priority: 100)
     ],
     defaultDomain: "general",
     evaluationStrategy: .highestPriority
 )
 llmManager.registerDomainRouter(router)
 ```
 */
public final class LogicDomainRouter: LLMDomainRouterProtocol {
    public let name: String
    public let supportedDomains: [String]

    private let rules: [LogicRule]
    private let defaultDomain: String?
    private let strategy: EvaluationStrategy
    private let logger: CustomLogger?

    /**
     - Parameters:
        - name: Identifier used in logs.
        - supportedDomains: Valid domain list.
        - rules: Ordered array of `LogicRule`s.
        - defaultDomain: Optional catch-all when nothing matches.
        - evaluationStrategy: See `EvaluationStrategy`.
        - logger: Optional custom logger.
     */
    public init(name: String,
                supportedDomains: [String],
                rules: [LogicRule],
                defaultDomain: String? = nil,
                evaluationStrategy: EvaluationStrategy = .firstMatch,
                logger: CustomLogger? = nil)
    {
        self.name = name
        self.supportedDomains = supportedDomains.map { $0.lowercased() }
        self.rules = rules
        self.defaultDomain = defaultDomain?.lowercased()
        strategy = evaluationStrategy
        self.logger = logger
    }

    /**
     Applies the chosen `EvaluationStrategy` and returns a domain
     or `nil` if unresolved.
     */
    public func determineDomain(for request: LLMRequest) async throws -> String? {
        switch strategy {
        case .firstMatch:
            for r in rules where r.predicate(request) {
                logger?.debug("[\(name)] '\(r.name)' matched → \(r.domain)",
                              category: "LogicDomainRouter")
                return r.domain
            }

        case .highestPriority:
            var winner: LogicRule?
            for r in rules where r.predicate(request) {
                if winner == nil || r.priority > winner!.priority { winner = r }
            }
            if let win = winner {
                logger?.debug("[\(name)] '\(win.name)' matched (highestPriority \(win.priority))",
                              category: "LogicDomainRouter")
                return win.domain
            }

        case let .topKThenResolve(k, resolver):
            var bucket: [LogicRule] = []
            for r in rules where r.predicate(request) {
                bucket.append(r)
                if bucket.count == k { break }
            }
            if let result = resolver(bucket) {
                logger?.debug("[\(name)] topK resolver chose '\(result)'", category: "LogicDomainRouter")
                return result.lowercased()
            }

        case .probabilisticWeights(let selector, var rng):
            let matches = rules.filter { $0.predicate(request) }
            let weighted = selector(matches)
            if let choice = Self.weightedRandom(weighted, using: &rng) {
                logger?.debug("[\(name)] probabilistic picked '\(choice)'",
                              category: "LogicDomainRouter")
                return choice
            }

        case let .custom(resolver):
            let matches = rules.filter { $0.predicate(request) }
            if let result = resolver(matches) {
                logger?.debug("[\(name)] custom resolver chose '\(result)'", category: "LogicDomainRouter")
                return result.lowercased()
            }
        }

        logger?.debug("[\(name)] no rule matched → \(defaultDomain ?? "nil")",
                      category: "LogicDomainRouter")
        return defaultDomain
    }

    /// Helper for weighted random draw.
    private static func weightedRandom(
        _ items: [(domain: String, weight: Double)],
        using rng: inout RandomNumberGenerator
    ) -> String? {
        let total = items.reduce(0) { $0 + max($1.weight, 0) }
        guard total > 0 else { return nil }

        let r = Double.random(in: 0 ..< total, using: &rng)
        var running = 0.0
        for item in items {
            running += max(item.weight, 0)
            if r < running { return item.domain }
        }
        return nil
    }
}

// MARK: - Convenience Rule Builders

public extension LogicRule {
    /** Regex/keyword match (case-insensitive, Unicode-aware). */
    static func regex(name: String,
                      pattern: String,
                      domain: String,
                      priority: Int = 0) -> LogicRule
    {
        let rx = try? NSRegularExpression(pattern: pattern,
                                          options: [.caseInsensitive])
        return LogicRule(name: name, domain: domain, priority: priority) { req in
            let text = req.messages.map(\.content).joined(separator: " ")
            return rx?.firstMatch(in: text,
                                  options: [],
                                  range: NSRange(text.startIndex..., in: text)) != nil
        }
    }

    /** Match on estimated token count with a custom comparison closure. */
    static func tokens(name: String,
                       domain: String,
                       priority: Int = 0,
                       cmp: @escaping (Int) -> Bool) -> LogicRule
    {
        LogicRule(name: name, domain: domain, priority: priority) { req in
            cmp(req.estimatedTokenCount())
        }
    }

    /** Match when local hour falls inside `hours`. */
    static func hours(name: String,
                      hours: ClosedRange<Int>,
                      domain: String,
                      priority: Int = 0,
                      clock: @escaping () -> Date = { Date() }) -> LogicRule
    {
        LogicRule(name: name, domain: domain, priority: priority) { _ in
            hours.contains(Calendar.current.component(.hour, from: clock()))
        }
    }
}
