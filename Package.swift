// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IrisDownloader",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "IrisDownloader",
            path: "Sources/IrisDownloader"
        )
    ]
)
