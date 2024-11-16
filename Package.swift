// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AuroraCore",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "AuroraCore",
            targets: ["AuroraCore"]),
        .executable(
            name: "Examples",
            targets: ["Examples"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AuroraCore",
            dependencies: [],
            path: "Sources/AuroraCore"
        ),
        .testTarget(
            name: "AuroraCoreTests",
            dependencies: ["AuroraCore"],
            path: "Tests/AuroraCoreTests"
        ),
        .executableTarget(
            name: "Examples",
            dependencies: ["AuroraCore"],
            path: "Sources/Examples"
        )
    ]
)
