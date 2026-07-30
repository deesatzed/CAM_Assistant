// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CAMAssistant",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "CAMAssistantCore", targets: ["CAMAssistantCore"]),
        .executable(name: "CAMAssistant", targets: ["CAMAssistantApp"]),
        .executable(name: "cam-assistant", targets: ["CAMAssistantCLI"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/deesatzed/meaningcore.git",
            revision: "23db68044ebdc410edf3b7f436e433ffba6e94b8"
        ),
    ],
    targets: [
        .target(
            name: "CAMAssistantCore",
            dependencies: [
                .product(name: "MeaningCore", package: "meaningcore"),
            ],
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .executableTarget(
            name: "CAMAssistantApp",
            dependencies: ["CAMAssistantCore"]
        ),
        .executableTarget(
            name: "CAMAssistantCLI",
            dependencies: ["CAMAssistantCore"]
        ),
        .testTarget(
            name: "CAMAssistantCoreTests",
            dependencies: [
                "CAMAssistantCore",
                .product(name: "MeaningCore", package: "meaningcore"),
            ]
        ),
        .testTarget(
            name: "CAMAssistantAppTests",
            dependencies: ["CAMAssistantApp"]
        ),
    ]
)
