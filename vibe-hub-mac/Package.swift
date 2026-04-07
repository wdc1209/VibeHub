// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "VibeHub",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "VibeHub", targets: ["VibeHub"])
    ],
    targets: [
        .executableTarget(
            name: "VibeHub",
            path: "VibeHubApp",
            exclude: ["Assets"]
        )
    ]
)
