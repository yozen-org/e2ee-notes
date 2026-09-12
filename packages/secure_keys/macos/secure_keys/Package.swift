// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "secure_keys",
    platforms: [
        .macOS("12.0")
    ],
    products: [
        .library(name: "secure-keys", targets: ["secure_keys"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "secure_keys",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [

            ]
        )
    ]
)
