// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "restage",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "RestageKit"),
        .target(name: "RestageKitDarwin", dependencies: ["RestageKit"]),
        .executableTarget(name: "restage", dependencies: ["RestageKit", "RestageKitDarwin"]),
        .testTarget(name: "RestageKitTests", dependencies: ["RestageKit"]),
        .testTarget(name: "RestageKitDarwinTests", dependencies: ["RestageKitDarwin"]),
    ]
)
