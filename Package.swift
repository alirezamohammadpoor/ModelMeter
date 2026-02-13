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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.4")
    ],
    targets: [
        .target(
            name: "ModelMeterCore"
        ),
        .executableTarget(
            name: "ModelMeterApp",
            dependencies: [
                "ModelMeterCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            exclude: [
                "Info.plist"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ModelMeterCoreTests",
            dependencies: ["ModelMeterCore"]
        ),
        .testTarget(
            name: "ModelMeterAppTests",
            dependencies: ["ModelMeterApp"]
        )
    ]
)
