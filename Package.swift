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
    targets: [
        .target(
            name: "CAMAssistantCore",
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
            dependencies: ["CAMAssistantCore"]
        ),
        .testTarget(
            name: "CAMAssistantAppTests",
            dependencies: ["CAMAssistantApp"]
        ),
    ]
)
