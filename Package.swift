// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "audio-video-merger",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AudioVideoMerger", targets: ["AudioVideoMerger"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1")
    ],
    targets: [
        .executableTarget(
            name: "AudioVideoMerger",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "src"
        ),
        .testTarget(
            name: "AudioVideoMergerTests",
            dependencies: ["AudioVideoMerger"],
            path: "Tests/AudioVideoMergerTests"
        )
    ]
)
