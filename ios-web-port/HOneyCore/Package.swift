// swift-tools-version:5.10
// HOneyCore — the platform-neutral layer of the iPhone port: wire DTOs,
// the API clients, domain rules (period catalog, course display, Home
// timing), the composer state machine, feed paging and the local stores.
// No UIKit/SwiftUI/Security here, so the whole package builds and tests on
// Linux (the droplet has no Xcode) as well as inside the app target.
import PackageDescription

let package = Package(
    name: "HOneyCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HOneyCore", targets: ["HOneyCore"]),
    ],
    targets: [
        .target(
            name: "HOneyCore",
            path: "Sources/HOneyCore",
            swiftSettings: [.enableUpcomingFeature("BareSlashRegexLiterals")]
        ),
        .testTarget(
            name: "HOneyCoreTests",
            dependencies: ["HOneyCore"],
            path: "Tests/HOneyCoreTests"
        ),
    ]
)
