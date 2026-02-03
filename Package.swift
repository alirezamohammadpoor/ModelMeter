// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ModelMeter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ModelMeterApp", targets: ["ModelMeterApp"]),
        .library(name: "ModelMeterCore", targets: ["ModelMeterCore"])
    ],
    targets: [
        .target(
            name: "ModelMeterCore"
        ),
        .executableTarget(
            name: "ModelMeterApp",
            dependencies: ["ModelMeterCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ModelMeterCoreTests",
            dependencies: ["ModelMeterCore"]
        )
    ]
)
