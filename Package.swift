// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TrueType",
    platforms: [
        .iOS(.v14),
        .tvOS(.v14),
    ],
    products: [
        .library(
            name: "TrueType",
            targets: ["TrueType"]
        ),
    ],
    targets: [
        // 主 Swift target：开关配置、swizzle、SwiftUI 支持。
        .target(
            name: "TrueType",
            dependencies: ["TrueTypeAutoStart"]
        ),
        // 仅含 Objective-C `+load` 的引导 target，实现「引入即生效」。
        .target(
            name: "TrueTypeAutoStart"
        ),
    ],
    swiftLanguageModes: [.v6]
)
