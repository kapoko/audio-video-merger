// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "swift-test",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "swift-test", targets: ["swift-test"])
    ],
    targets: [
        .executableTarget(name: "swift-test", path: "src")
    ]
)
