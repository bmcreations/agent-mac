// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "agent-mac-runner",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "agent-mac-runner", path: "Sources"),
    ]
)
