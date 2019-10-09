// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Hypershard",
    products: [
        .executable(
            name: "hypershard",
            targets: [ "Hypershard" ])
        ],
    dependencies: [
        .package(url: "https://github.com/kylef/PathKit.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/jpsim/SourceKitten.git", .upToNextMajor(from: "0.26.0")),
        .package(url: "https://github.com/kylef/Commander.git", .upToNextMajor(from: "0.9.1")),
        .package(url: "https://github.com/tuist/Xcodeproj.git", .upToNextMajor(from: "7.1.0"))
        ],
    targets: [
        .target(
            name: "Hypershard",
            dependencies: [
                "HypershardCore"
                ]
        ),
        .target(
            name: "HypershardCore",
            dependencies: [
                "SourceKittenFramework",
                "PathKit",
                "Commander",
                "XcodeProj"
                ]
        ),
        .testTarget(
            name: "HypershardCoreTests",
            dependencies: [
                "HypershardCore"
                ],
            path: "Tests"
        )
    ]
)
