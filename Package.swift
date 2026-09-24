// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TokenMeter",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "TokenMeter"),
        .testTarget(name: "TokenMeterTests", dependencies: ["TokenMeter"]),
    ]
)
