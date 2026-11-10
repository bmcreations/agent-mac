// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "agent-vm-runner",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "agent-vm-runner", path: "Sources"),
    ]
)
