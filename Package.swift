// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Cicada",
    platforms: [.iOS(.v13), .macOS(.v26), .tvOS(.v26), .watchOS(.v26), .visionOS(.v26)],
    products: [
        .library(
            name: "Cicada",
            targets: ["Cicada"]
        ),
    ],
    targets: [
        .target(
            name: "Cicada",
            path: "Sources"
        ),
        .testTarget(
            name: "CicadaTests",
            dependencies: ["Cicada"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
