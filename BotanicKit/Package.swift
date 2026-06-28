// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BotanicKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "BotanicKit", targets: ["BotanicKit"])
    ],
    targets: [
        .target(name: "BotanicKit"),
        .testTarget(name: "BotanicKitTests", dependencies: ["BotanicKit"])
    ]
)
