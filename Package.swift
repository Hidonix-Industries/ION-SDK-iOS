// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "ion_ios",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "ion_ios",
            targets: ["ion_ios"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "ion_ios",
            path: "./ion_ios.xcframework"
        )
    ]
)
