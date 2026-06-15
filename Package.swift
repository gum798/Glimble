// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Glimble",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "GlimbleCore", targets: ["GlimbleCore"]),
    ],
    targets: [
        .target(name: "GlimbleCore"),
        .testTarget(name: "GlimbleCoreTests", dependencies: ["GlimbleCore"]),
    ]
)
