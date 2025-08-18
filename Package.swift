// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "swift-test",
    platforms: [
        .macOS(.v10_14)
    ],
    targets: [
        .target(name: "swift-test", path: "src")
    ]
)
