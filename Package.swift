// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Minefield",
    defaultLocalization: "zh-Hant",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Minefield",
            targets: ["Minefield"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Minefield",
            dependencies: [],
            path: "Sources/Minefield"
        ),
        .testTarget(
            name: "MinefieldTests",
            dependencies: ["Minefield"],
            path: "Tests/MinefieldTests"
        ),
    ]
)
