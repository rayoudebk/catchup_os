// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Catchup",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Catchup",
            targets: ["Catchup"]),
    ],
    targets: [
        .target(
            name: "Catchup"),
    ]
)

