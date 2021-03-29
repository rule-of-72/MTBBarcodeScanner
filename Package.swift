// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "MTBBarcodeScanner",
    platforms: [.iOS(.v9)],
    products: [
        .library(
            name: "MTBBarcodeScanner",
            targets: ["MTBBarcodeScanner"]
        )
    ],
    targets: [
        .target(
            name: "MTBBarcodeScanner",
            path: "Classes/ios",
            publicHeadersPath: "."
        )
    ]
)
