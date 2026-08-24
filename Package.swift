// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "restage",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "RestageKit", dependencies: [.product(name: "Yams", package: "Yams")],
            resources: [.process("Resources")]),
        .target(name: "RestageKitDarwin", dependencies: ["RestageKit"]),
        .target(name: "RestageBrand"),
        .executableTarget(
            name: "restage", dependencies: ["RestageKit", "RestageKitDarwin", "RestageBrand"]),
        .executableTarget(name: "restage-icon", dependencies: ["RestageBrand"]),
        .testTarget(name: "RestageKitTests", dependencies: ["RestageKit"]),
        .testTarget(name: "RestageKitDarwinTests", dependencies: ["RestageKitDarwin"]),
    ]
)
