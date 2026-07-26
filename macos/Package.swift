// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HideMyEmailGenerator",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "HideMyEmailGenerator", targets: ["HideMyEmailGenerator"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            exact: "2.9.4"
        )
    ],
    targets: [
        .executableTarget(
            name: "HideMyEmailGenerator",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks",
                ])
            ]
        ),
        .testTarget(
            name: "HideMyEmailGeneratorTests",
            dependencies: ["HideMyEmailGenerator"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
