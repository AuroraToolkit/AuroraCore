// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AuroraToolkit",
    platforms: [
        .iOS(.v14),
        .macOS(.v14)
    ],
    products: [
        // Core library
        .library(
            name: "AuroraCore",
            targets: ["AuroraCore"]
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
    dependencies: [
        .package(url: "https://github.com/eastriverlee/LLM.swift.git", branch: "main")
    ],
    targets: [
        // Core
        .target(
            name: "AuroraCore",
            dependencies: [],
            path: "Sources/AuroraCore"
        ),
        // LLM management
        .target(
            name: "AuroraLLM",
            dependencies: [
                "AuroraCore",
                .product(name: "LLM", package: "LLM.swift") // Local llama model support
            ],
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
