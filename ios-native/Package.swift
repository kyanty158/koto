// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KotoKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "KotoKit",
            targets: ["KotoKit"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "KotoKit",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "KotoKitTests",
            dependencies: ["KotoKit"],
            path: "Tests"
        ),
    ]
)
