// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CurrencyField",
    platforms: [
        .iOS(.v14), .tvOS(.v14)
    ],
    products: [
        .library(name: "CurrencyField", targets: ["CurrencyField"])
    ],
    targets: [
        .target(name: "CurrencyField")
    ]
)
