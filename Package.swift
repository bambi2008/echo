// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "EchoAI",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "EchoAI", targets: ["EchoAI"]),
    ],
    targets: [
        .target(name: "EchoAI"),
        .testTarget(name: "EchoAITests", dependencies: ["EchoAI"]),
    ]
)
