// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HideMyEmailGenerator",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "HideMyEmailGenerator", targets: ["HideMyEmailGenerator"])
    ],
    targets: [
        .executableTarget(name: "HideMyEmailGenerator"),
        .testTarget(
            name: "HideMyEmailGeneratorTests",
            dependencies: ["HideMyEmailGenerator"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
