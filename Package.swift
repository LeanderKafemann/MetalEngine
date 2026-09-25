// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MetalEngine",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MetalEngine",
            path: "Sources/MetalEngine",
            resources: [
                .process("Shaders/Shaders.metal")
            ],
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("QuartzCore")
            ]
        )
    ]
)
