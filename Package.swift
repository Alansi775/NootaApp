// Noota/Package.swift
// Add this `Package.swift` at the root of your Xcode project
// This is for local Swift Package Manager dependencies, specifically the mock Google Cloud client.
// In a real project, you would typically integrate Google's official Swift gRPC client here.

import PackageDescription

let package = Package(
    name: "Noota",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Noota",
            targets: ["Noota"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "10.0.0")),
        .package(url: "https://github.com/malcommac/Swift-QRCodeGenerator.git", .upToNextMajor(from: "2.0.0"))
        // You would typically add Google Cloud Swift client here.
        // For this example, we're simulating the Google Cloud part with a local package.
        // .package(url: "https://github.com/grpc/grpc-swift.git", .upToNextMajor(from: "1.0.0")),
        // .package(url: "https://github.com/googleapis/google-cloud-swift.git", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(
            name: "Noota",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestoreSwift", package: "firebase-ios-sdk"),
                .product(name: "QRCodeGenerator", package: "Swift-QRCodeGenerator")
                // For Google Cloud streaming, you would need a custom target that uses gRPC Swift and Protobufs for Translation API
                // For this project, GoogleCloudTranslationStreaming is a local placeholder for illustration.
                // It means you would create a local Swift Package `GoogleCloudTranslationStreaming` in the `Packages` folder
                // and put your actual gRPC client code there.
            ],
            path: "Noota",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "NootaTests",
            dependencies: ["Noota"]),
        .testTarget(
            name: "NootaUITests",
            dependencies: ["Noota"]),
    ]
)