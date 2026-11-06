// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Tendedero",
    platforms: [.macOS(.v14)],
    dependencies: [
        // The rules for the apps that take screenshots, on their own, so they
        // can be built for another system.
        .package(path: "TendederoCore")
    ],
    targets: [
        // Resources holds the translations. scripts/build-app.sh copies them
        // into the app, so SwiftPM leaves them alone.
        .executableTarget(
            name: "Tendedero",
            dependencies: [.product(name: "TendederoCore", package: "TendederoCore")],
            path: "Sources/Tendedero",
            exclude: ["Resources"]
        )
    ]
)
