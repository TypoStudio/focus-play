// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "FocusPlay",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "FocusPlay",
            path: "Sources/FocusPlay",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
