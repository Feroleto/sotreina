// swift-tools-version: 6.0

import PackageDescription

// Platform-neutral logic shared by the app and its Live Activity extension.
// Must keep compiling on Linux (`swift test` here, no simulator exists off
// macOS) — anything Apple-only goes behind `#if canImport(...)`.
let package = Package(
    name: "SoTreinaKit",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(name: "SoTreinaKit", targets: ["SoTreinaKit"]),
    ],
    targets: [
        .target(name: "SoTreinaKit"),
        .testTarget(
            name: "SoTreinaKitTests",
            dependencies: ["SoTreinaKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
