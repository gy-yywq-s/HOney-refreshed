// swift-tools-version:5.10
// HOneyCore — the platform-neutral layer of the iPhone port: wire DTOs,
// the API clients, domain rules (period catalog, course display, Home
// timing), the composer state machine, feed paging, the local stores and
// the Anonymous Control v2 client (key hierarchy, vault, wrappers,
// recovery words, pairing, blind tokens). No UIKit/SwiftUI/Security here,
// so the whole package builds and tests on Linux (the droplet has no
// Xcode) as well as inside the app target.
//
// Dependencies: swift-crypto (HKDF, Ed25519, AES-GCM, HPKE, SHA-384 — the
// same primitives CryptoKit exposes on-device) and BigInt (the modular
// arithmetic of the partially-blind RSA client; swift-crypto's RSA cannot
// host the derived exponent).
import PackageDescription

let package = Package(
    name: "HOneyCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HOneyCore", targets: ["HOneyCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.8.0"),
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.3.0"),
    ],
    targets: [
        .target(
            name: "HOneyCore",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "BigInt", package: "BigInt"),
            ],
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
