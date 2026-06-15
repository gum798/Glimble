// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Glimble",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "GlimbleCore", targets: ["GlimbleCore"]),
        .executable(name: "GlimbleSpike", targets: ["GlimbleSpike"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Kyome22/OpenMultitouchSupport.git", exact: "4.0.0"),
    ],
    targets: [
        .target(name: "GlimbleCore"),
        .executableTarget(
            name: "GlimbleSpike",
            dependencies: [
                "GlimbleCore",
                .product(name: "OpenMultitouchSupport", package: "OpenMultitouchSupport"),
            ],
            exclude: ["Info.plist"]
        ),
        .testTarget(name: "GlimbleCoreTests", dependencies: ["GlimbleCore"]),
    ]
)
