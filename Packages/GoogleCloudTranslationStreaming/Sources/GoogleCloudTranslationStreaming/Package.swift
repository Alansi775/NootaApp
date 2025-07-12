// Noota/Packages/GoogleCloudTranslationStreaming/Package.swift
// This is the Package.swift for the local GoogleCloudTranslationStreaming package.
// It would contain dependencies for gRPC Swift, Protobufs, etc., if it were a real client.

import PackageDescription

let package = Package(
    name: "GoogleCloudTranslationStreaming",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "GoogleCloudTranslationStreaming",
            targets: ["GoogleCloudTranslationStreaming"]),
    ],
    dependencies: [
        // In a real implementation, you'd include:
        // .package(url: "https://github.com/grpc/grpc-swift.git", .upToNextMajor(from: "1.0.0")),
        // .package(url: "https://github.com/apple/swift-protobuf.git", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(
            name: "GoogleCloudTranslationStreaming",
            dependencies: [] // Add gRPC and Protobuf dependencies here if used
        ),
        .testTarget(
            name: "GoogleCloudTranslationStreamingTests",
            dependencies: ["GoogleCloudTranslationStreaming"]),
    ]
)
