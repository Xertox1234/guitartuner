import Foundation
import CoreText
import os

/// Registers the bundled custom faces (Chakra Petch, JetBrains Mono) with the
/// system at runtime, so SwiftUI can resolve them via `.custom(_:size:)`.
///
/// Because the fonts ship inside this package's resource bundle (not the app's
/// `Info.plist` `UIAppFonts`), they must be registered programmatically. Call
/// `LumaFonts.registerIfNeeded()` once at launch (the app does this in its
/// `init`). If no `.ttf` files are present, this is a no-op and `LumaFont`
/// falls back to SF Pro Display / SF Mono.
public enum LumaFonts {
    private static let logger = Logger(subsystem: "com.luma.designsystem", category: "fonts")
    private static var didRegister = false

    /// Register every `.ttf` in the package's `Fonts` resource directory. Safe
    /// to call multiple times.
    public static func registerIfNeeded() {
        guard !didRegister else { return }
        didRegister = true

        let urls = (Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
            + (Bundle.module.urls(forResourcesWithExtension: "otf", subdirectory: "Fonts") ?? [])

        guard !urls.isEmpty else {
            logger.info("No bundled fonts found — falling back to system faces (SF Pro Display / SF Mono).")
            return
        }

        for url in urls {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // Already-registered is not a real failure; log others.
                logger.notice("Skipped \(url.lastPathComponent, privacy: .public): already registered or unavailable.")
            }
        }
    }
}
