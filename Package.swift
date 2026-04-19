// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "audio-video-merger",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "AudioVideoMerger", targets: ["AudioVideoMerger"])
    ],
    targets: [
        .executableTarget(name: "AudioVideoMerger", path: "src"),
        .testTarget(
            name: "AudioVideoMergerTests",
            dependencies: ["AudioVideoMerger"],
            path: "Tests/AudioVideoMergerTests"
        )
    ]
)
