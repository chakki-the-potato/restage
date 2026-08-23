// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "restage",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        .target(name: "RestageKit", dependencies: [.product(name: "Yams", package: "Yams")]),
        .target(name: "RestageKitDarwin", dependencies: ["RestageKit"]),
        .executableTarget(name: "restage", dependencies: ["RestageKit", "RestageKitDarwin"]),
        .testTarget(name: "RestageKitTests", dependencies: ["RestageKit"]),
        .testTarget(name: "RestageKitDarwinTests", dependencies: ["RestageKitDarwin"]),
    ]
)
