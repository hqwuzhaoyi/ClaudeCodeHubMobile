// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeCodeHubMobileCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ClaudeCodeHubMobileCore", targets: ["ClaudeCodeHubMobileCore"]),
    ],
    targets: [
        .target(
            name: "ClaudeCodeHubMobileCore",
            path: "ClaudeCodeHubMobile",
            exclude: [
                "App",
                "Features",
                "Core/Session",
                "Shared/SharedViews.swift",
                "ClaudeCodeHubMobileApp.swift",
                "ContentView.swift",
            ],
            sources: [
                "Core/Networking/APIClient.swift",
                "Core/Networking/APIError.swift",
                "Core/Networking/AnyJSON.swift",
                "Core/Models/UsageModels.swift",
                "Shared/Formatters/AppFormatters.swift",
            ]
        ),
        .testTarget(
            name: "ClaudeCodeHubMobileCoreTests",
            dependencies: ["ClaudeCodeHubMobileCore"],
            path: "Tests/ClaudeCodeHubMobileCoreTests"
        ),
    ]
)
