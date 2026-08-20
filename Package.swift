// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "quill",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.12.4"),
        // Local (no-key, no-cloud) Auto Cleanup tone rewriting — a small on-device
        // LLM via Apple's MLX, sitting between Light (rules-only) and Medium (BYOK).
        //
        // Pinned to 2.21.2, not latest: mlx-swift-examples 2.25+ bumped its
        // swift-transformers requirement to 1.x, which WhisperKit's own
        // swift-transformers 0.1.x pin can't satisfy — a genuine conflict
        // between the two, not fixable by version juggling alone. 2.21.2
        // still wants swift-transformers 0.1.x, compatible with WhisperKit.
        //
        // mlx-swift is pinned explicitly too: mlx-swift-examples 2.21.2's own
        // manifest only loosely bounds it (< next major), and without this
        // tighter pin SPM's whole-graph resolution silently grabbed a newer
        // mlx-swift that broke source compatibility with 2.21.2 (hit this:
        // resolved 0.31.6 against code built for 0.21.x, wouldn't compile).
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", exact: "2.21.2"),
        .package(url: "https://github.com/ml-explore/mlx-swift", .upToNextMinor(from: "0.21.2")),
        // Auto-update: background checks, native "update available" alert,
        // download + install, EdDSA signature verification against
        // SUPublicEDKey in Info.plist. The de facto standard for
        // non-App-Store Mac apps; replaces the hand-rolled GitHub-API
        // update checker (UpdateCheckView/GitHubReleases.latest()).
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "quill",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "MLXLMCommon", package: "mlx-swift-examples"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            // Official provider logos (Enhancement Engine) — SPM resources
            // must live inside the target's own source tree, unlike the
            // top-level Resources/ folder (app icon, DMG background),
            // which build-app.sh copies manually and isn't SPM-managed at
            // all. Loaded at runtime via the auto-generated `Bundle.module`
            // — see `ProviderLogos.swift`. build-app.sh separately copies
            // the generated `quill_quill.bundle` into the shipped .app,
            // same as it already does for AppIcon.icns/Info.plist.
            resources: [
                .copy("Resources/ProviderLogos")
            ]
        ),
    ]
)
