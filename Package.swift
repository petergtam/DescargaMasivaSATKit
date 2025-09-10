// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "Descarga Masiva SAT Kit",
    products: [
        .library(
            name: "DescargaMasivaSATKit",
            targets: ["DescargaMasivaSATKit"])
    ],
    targets: [
        .binaryTarget(
            name: "DescargaMasivaSATKit",
            path: "xcframeworks/DescargaMasivaSATKit.xcframework"
        )
    ]
)