// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BoozeBlocker",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "BoozeBlocker",
            targets: ["BoozeBlocker"]),
    ],
    targets: [
        .target(
            name: "BoozeBlocker",
            path: "BoozeBlocker"),
    ]
)
