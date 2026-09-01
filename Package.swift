// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "suparpad",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "suparpad", path: "Sources/suparpad"),
        .executableTarget(name: "pinchprobe", path: "Sources/pinchprobe"),
    ]
)
