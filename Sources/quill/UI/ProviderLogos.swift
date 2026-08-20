import AppKit
import SwiftUI

/// Loads the official provider logos for Enhancement Engine's provider
/// rows. These are each provider's own published mark, used only to
/// identify which service a row connects to — not modified, not
/// re-colored, not implying endorsement. First raster images this app has
/// ever needed to bundle at runtime (everything else so far is SF
/// Symbols).
///
/// Reads from `Bundle.main`'s `Contents/Resources/ProviderLogos/`
/// (`build-app.sh` copies the source PNGs there as loose files), the same
/// spot `AppIcon.icns` already lives in — deliberately NOT SPM's
/// generated `Bundle.module`/resource-bundle mechanism, even though
/// `Package.swift` still declares it (harmless, useful for a bare `swift
/// run`). That accessor's `mainPath` expects a `quill_quill.bundle`
/// sitting as a *sibling* of Contents/, which `codesign --deep` flatly
/// rejects for a hand-assembled .app ("unsealed contents present in the
/// bundle root") — confirmed directly, not guessed, since it broke
/// `build-app.sh` outright. Even setting that aside, `Bundle.module` is a
/// lazily-initialized global that calls `fatalError` if its two hardcoded
/// paths don't resolve — not something worth risking for a decorative
/// logo, so this file never touches it.
enum ProviderLogos {
    private static var cache: [StyleProvider: Image] = [:]

    static func image(for provider: StyleProvider) -> Image? {
        if let cached = cache[provider] { return cached }
        guard
            let url = Bundle.main.url(
                forResource: fileName(for: provider), withExtension: "png", subdirectory: "ProviderLogos"
            ),
            let nsImage = NSImage(contentsOf: url)
        else { return nil }
        let image = Image(nsImage: nsImage)
        cache[provider] = image
        return image
    }

    private static func fileName(for provider: StyleProvider) -> String {
        switch provider {
        case .openAI: return "openai"
        case .anthropic: return "anthropic"
        case .google: return "google"
        case .openRouter: return "openrouter"
        }
    }
}
