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
        // LLM via Apple's MLX, an alternative to Medium (BYOK) for anyone who'd
        // rather not touch the network at all.
        //
        // mlx-swift-lm, not the older mlx-swift-examples: MLXLLM/MLXLMCommon
        // (same product names, same import sites) moved into this separate,
        // actively-maintained package as of the mlx-swift-examples 2.29.x era —
        // confirmed via its Package.swift, it drops the swift-transformers
        // dependency entirely, which is what forced the old mlx-swift-examples
        // pin to 2.21.2 in the first place (2.25+ wanted swift-transformers 1.x,
        // WhisperKit's own pin at the time only went to 0.1.x — a real conflict,
        // not fixable by version juggling alone). That conflict doesn't apply
        // here since this package doesn't touch swift-transformers at all.
        //
        // The actual reason for this switch: mlx-swift 0.21.x's bundled Metal
        // shader library predates the Apple M5 GPU entirely, and the very first
        // MLX model load on M5 hardware reliably crashes the whole app —
        // confirmed via a real crash report (SIGABRT, std::terminate inside
        // mlx::core::scheduler::StreamThread's constructor, triggered from
        // Device._defaultStream's lazy init). mlx-swift 0.31.4+ is from well
        // after M5 shipped (Apple's own MLX research confirms M5 GPU support
        // needs macOS >= 26.2 — this Mac qualifies) and mlx-swift-lm requires
        // exactly that range.
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", exact: "3.31.4"),
        .package(url: "https://github.com/ml-explore/mlx-swift", .upToNextMinor(from: "0.31.4")),
        // mlx-swift-lm's own `loadContainer` no longer bundles a default
        // Hugging Face downloader/tokenizer-loader (that's the whole reason
        // it could drop swift-transformers) — it expects the app to supply
        // one via MLXHuggingFace's `#huggingFaceLoadModelContainer` macro,
        // which itself expects this specific package (`import HuggingFace`,
        // literally referenced by name in the macro's generated code).
        // No swift-transformers dependency here either, confirmed via its
        // own Package.swift — doesn't reopen the WhisperKit conflict.
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
        // MLXHuggingFace's own macro-generated code references `Tokenizers`
        // by name at the call site (confirmed via its Macros.swift doc
        // examples) — target dependencies aren't transitive for `import`
        // visibility, so this target needs its own explicit dependency to
        // import the `Tokenizers` module itself.
        //
        // Pinned at 1.1.6+, not WhisperKit 0.14.1's old 0.1.x range: the
        // macro's generated code calls `Tokenizer.applyChatTemplate(...)`
        // with the `[String: any Sendable]` signature and throws
        // `Tokenizers.TokenizerError.missingChatTemplate` — both added in
        // swift-transformers 1.1.6 (confirmed via its own git history), not
        // present in 0.1.15. WhisperKit itself moved to swift-transformers
        // 1.1.6+ as of its own 0.18.0 release (confirmed via WhisperKit's
        // Package.swift) — this target's `from: "0.9.0"` WhisperKit pin has
        // no upper bound, so the resolver is free to pick a WhisperKit
        // version compatible with this, not stuck at 0.14.1.
        .package(url: "https://github.com/huggingface/swift-transformers.git", .upToNextMinor(from: "1.1.6")),
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
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Transformers", package: "swift-transformers"),
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
