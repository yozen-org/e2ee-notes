// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "hardware_keys",
    platforms: [
        .macOS("12.0")
    ],
    products: [
        .library(name: "hardware-keys", targets: ["hardware_keys"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "hardware_keys",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [

            ]
        )
    ]
)
