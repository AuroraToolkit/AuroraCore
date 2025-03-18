// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AuroraToolkit",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        // Core library
        .library(
            name: "AuroraCore",
            targets: ["AuroraCore"]
        ),
        // Agent library
        .library(
            name: "AuroraAgent",
            targets: ["AuroraAgent"]
        ),
        // LLM management
        .library(
            name: "AuroraLLM",
            targets: ["AuroraLLM"]
        ),
        // Task library
        .library(
            name: "AuroraTaskLibrary",
            targets: ["AuroraTaskLibrary"]
        ),
        // Examples
        .executable(
            name: "AuroraExamples",
            targets: ["AuroraExamples"]
        )
    ],
    dependencies: [],
    targets: [
        // Core
        .target(
            name: "AuroraCore",
            dependencies: [],
            path: "Sources/AuroraCore"
        ),
        // Agent
        .target(
            name: "AuroraAgent",
            dependencies: ["AuroraCore", "AuroraLLM", "AuroraTaskLibrary"],
            path: "Sources/AuroraAgent"
        ),
        // LLM management
        .target(
            name: "AuroraLLM",
            dependencies: ["AuroraCore"],
            path: "Sources/AuroraLLM"
        ),
        // Task library
        .target(
            name: "AuroraTaskLibrary",
            dependencies: ["AuroraCore", "AuroraLLM"],
            path: "Sources/AuroraTaskLibrary"
        ),
        // Examples
        .executableTarget(
            name: "AuroraExamples",
            dependencies: ["AuroraCore", "AuroraLLM", "AuroraTaskLibrary"],
            path: "Sources/AuroraExamples"
        ),
        // Test targets
        .testTarget(
            name: "AuroraCoreTests",
            dependencies: ["AuroraCore"],
            path: "Tests/AuroraCoreTests"
        ),
        .testTarget(
            name: "AuroraAgentTests",
            dependencies: ["AuroraAgent"],
            path: "Tests/AuroraAgentTests"
        ),
        .testTarget(
            name: "AuroraLLMTests",
            dependencies: ["AuroraLLM"],
            path: "Tests/AuroraLLMTests"
        ),
        .testTarget(
            name: "AuroraTaskLibraryTests",
            dependencies: ["AuroraTaskLibrary"],
            path: "Tests/AuroraTaskLibraryTests"
        )
    ]
)
