// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SampleApp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "app", targets: ["app"])
    ],
    targets: [
        .target(name: "SampleCore", resources: [.copy("Resources/Vectors")]),
        .executableTarget(name: "app", dependencies: ["SampleCore"])
    ],
    swiftLanguageModes: [.v6]
)
