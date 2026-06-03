// swift-tools-version: 5.9
import PackageDescription

// LumaDesignSystem — the LUMA design-system layer translated to SwiftUI.
// Tokens (colour/type/spacing/radius/glow), the bloom modifier, a static
// component library, and a Design-System Gallery. No tuner/DSP logic.
let package = Package(
    name: "LumaDesignSystem",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "LumaDesignSystem", targets: ["LumaDesignSystem"])
    ],
    targets: [
        .target(
            name: "LumaDesignSystem",
            resources: [
                // Colour tokens as an asset catalog (Any/light + Dark appearances)
                // so the system resolves the theme. Read via LumaColor / Color.luma*.
                .process("Resources/Colors.xcassets"),
                // Font drop-in slot. Chakra Petch + JetBrains Mono .ttf go here and
                // are registered at runtime by LumaFonts.registerIfNeeded(); absent
                // fonts fall back to SF Pro Display / SF Mono.
                .copy("Resources/Fonts")
            ]
        ),
        .testTarget(
            name: "LumaDesignSystemTests",
            dependencies: ["LumaDesignSystem"]
        )
    ]
)
