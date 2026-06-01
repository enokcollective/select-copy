// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SelectCopy",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SelectCopy",
            path: "Sources/SelectCopy"
        )
    ]
)
