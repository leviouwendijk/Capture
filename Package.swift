// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Capture",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Capture",
            targets: ["Capture"]
        ),
        .executable(
            name: "capture",
            targets: ["CaptureCLI"]
        ),
        .executable(
            name: "ctest",
            targets: ["CaptureTestFlows"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Terminal.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Arguments.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/TestFlows.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "Capture"
        ),
        .executableTarget(
            name: "CaptureCLI",
            dependencies: [
                "Capture",
                .product(name: "Terminal", package: "Terminal"),
                .product(name: "Arguments", package: "Arguments"),
            ]
        ),
        .executableTarget(
            name: "CaptureTestFlows",
            dependencies: [
                "Capture",
                .product(name: "TestFlows", package: "TestFlows"),
            ]
        ),
    ]
)
