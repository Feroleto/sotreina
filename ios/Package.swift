// swift-tools-version: 6.0

import PackageDescription

// Built and installed by xtool (`xtool dev run`), not Xcode. Every root
// library product is an app bundle: `SoTreina` is the app and
// `SoTreinaLiveActivity` its widget extension (wired up in xtool.yml).
// Pure logic lives in the separate local package SoTreinaKit so it can be
// tested on Linux with `swift test` — this package only builds for iOS.
let package = Package(
    name: "SoTreina",
    defaultLocalization: "pt",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(name: "SoTreina", targets: ["SoTreina"]),
        .library(name: "SoTreinaLiveActivity", targets: ["SoTreinaLiveActivity"]),
    ],
    dependencies: [
        .package(path: "SoTreinaKit"),
    ],
    targets: [
        .target(
            name: "SoTreina",
            dependencies: ["SoTreinaKit"]
        ),
        .target(
            name: "SoTreinaLiveActivity",
            dependencies: ["SoTreinaKit"]
        ),
    ]
)
