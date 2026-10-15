// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "ion_ios",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // TensorFlowLiteC ships alongside ion_ios rather than inside it: an xcframework holds a
        // single product per platform slice, and ion_ios.framework carries the TFLite interpreter
        // as a strong LC_LOAD_DYLIB at @rpath. Without the framework in the product, the consuming
        // app never embeds or signs it and dyld fails at launch.
        .library(
            name: "ion_ios",
            targets: ["ion_ios", "TensorFlowLiteC"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "ion_ios",
            path: "./ion_ios.xcframework"
        ),
        .binaryTarget(
            name: "TensorFlowLiteC",
            path: "./TensorFlowLiteC.xcframework"
        )
    ]
)
