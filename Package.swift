// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "suparpad",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "pinchkit", path: "Sources/pinchkit"),
        .executableTarget(name: "suparpad", dependencies: ["pinchkit"], path: "Sources/suparpad"),
        .executableTarget(name: "pinchprobe", path: "Sources/pinchprobe"),
    ]
)
