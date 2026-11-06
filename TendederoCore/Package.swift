// swift-tools-version:5.9
import PackageDescription

// What Tendedero knows about the apps that take screenshots: which apps they
// are, what they call their files, and where their pictures are looked for.
//
// Nothing in here is macOS-only. The host says where apps are kept and where
// pictures land (see CapturePlatform); the rules are the same everywhere.
let package = Package(
    name: "TendederoCore",
    products: [
        .library(name: "TendederoCore", targets: ["TendederoCore"])
    ],
    targets: [
        .target(name: "TendederoCore"),
        // The checks are a plain program rather than tests: XCTest is not part
        // of the Command Line Tools, and this way they run wherever Swift does.
        .executableTarget(name: "CaptureAppsCheck", dependencies: ["TendederoCore"])
    ]
)
