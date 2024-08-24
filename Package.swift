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
    ],
    targets: [
        .target(
            name: "AuroraCore"),
        .testTarget(
            name: "AuroraCoreTests",
            dependencies: ["AuroraCore"]),
    ]
)
