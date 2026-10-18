// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MoonlightCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "MoonlightCore", targets: ["MoonlightCore"])
    ],
    targets: [
        .target(name: "MoonlightCore"),
        .testTarget(
            name: "MoonlightCoreTests",
            dependencies: ["MoonlightCore"]
        )
    ]
)
