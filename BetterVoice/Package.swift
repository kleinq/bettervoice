// swift-tools-version: 5.9
// SPM Package definition for BetterVoice dependencies

import PackageDescription

let package = Package(
    name: "BetterVoice",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "BetterVoice",
            targets: ["BetterVoice"])
    ],
    dependencies: [
        // GRDB.swift for SQLite database (learning patterns)
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0")
    ],
    targets: [
        .target(
            name: "BetterVoice",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        )
    ]
)
