// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "RecordButton",
    platforms: [
        .iOS(.v10),
    ],
    products: [
        .library(name: "RecordButton", targets: ["RecordButton"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "RecordButton"),
    ])
