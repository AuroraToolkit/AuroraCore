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
        // LLM management
        .library(
            name: "AuroraLLM",
            targets: ["AuroraLLM"]
        ),
        // ML management
        .library(
            name: "AuroraML",
            targets: ["AuroraML"]
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
        ),
        // Tools
        .executable(
            name: "ModelTrainer",
            targets: ["ModelTrainer"]
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
        // LLM management
        .target(
            name: "AuroraLLM",
            dependencies: ["AuroraCore"],
            path: "Sources/AuroraLLM"
        ),
        // ML management
        .target(
            name: "AuroraML",
            dependencies: ["AuroraCore"],
            path: "Sources/AuroraML"
        ),
        // Task library
        .target(
            name: "AuroraTaskLibrary",
            dependencies: ["AuroraCore", "AuroraLLM", "AuroraML"],
            path: "Sources/AuroraTaskLibrary"
        ),
        // Examples
        .executableTarget(
            name: "AuroraExamples",
            dependencies: ["AuroraCore", "AuroraLLM", "AuroraML", "AuroraTaskLibrary"],
            path: "Sources/AuroraExamples"
        ),
        // Tools
        .executableTarget(
            name: "ModelTrainer",
            dependencies: ["AuroraML"],
            path: "Sources/Tools/ModelTrainer"
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
            name: "AuroraMLTests",
            dependencies: ["AuroraML"],
            path: "Tests/AuroraMLTests"
        ),
        .testTarget(
            name: "AuroraTaskLibraryTests",
            dependencies: ["AuroraTaskLibrary"],
            path: "Tests/AuroraTaskLibraryTests"
        )
    ]
)
