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
        .package(url: "https://github.com/kapoko/sparkle-updater", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "AudioVideoMerger",
            dependencies: [
                .product(name: "SparkleUpdater", package: "sparkle-updater")
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
