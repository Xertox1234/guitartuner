---
name: swiftui-multiplatform
description: Use when building or modifying SwiftUI views that target both iOS and macOS — platform-conditional compilation, NavigationSplitView vs NavigationStack, @Observable state, Settings scenes, toolbar differences, window management, or Mac Catalyst vs native Mac (AppKit) distinctions.
---

# SwiftUI Multiplatform

LUMA targets iPhone, iPad, and Mac as a **native multiplatform app** (not Catalyst). One SwiftUI codebase, platform-specific behaviour via conditionals and adaptive components.

## Platform Conditionals

```swift
// Compile-time — use for API that doesn't exist on a platform
#if os(macOS)
Settings { SettingsView() }
#endif

// Runtime — use for layout/behaviour differences where API exists on both
if #available(macOS 14, iOS 17, *) {
    // @Observable path
}

// View modifier helper to keep call-sites clean
extension View {
    @ViewBuilder
    func iOSOnly(_ modifier: (Self) -> some View) -> some View {
        #if os(iOS)
        modifier(self)
        #else
        self
        #endif
    }
}
```

## Navigation

| Pattern | When to use |
|---------|-------------|
| `NavigationSplitView` | Mac, iPad (sidebar + detail) |
| `NavigationStack` | iPhone (push navigation) |
| Combine both | Mac/iPad uses split; iPhone collapses to stack |

```swift
// Adaptive navigation — single codebase
NavigationSplitView {
    Sidebar(selection: $selection)
} detail: {
    NavigationStack(path: $path) {
        DetailView(selection: $selection)
    }
}
// On iPhone, NavigationSplitView automatically collapses to a single column
```

## State — @Observable (iOS 17+ / macOS 14+)

Prefer `@Observable` over `ObservableObject`. It only re-renders views that read a changed property — finer granularity, less boilerplate.

```swift
// New (iOS 17+, macOS 14+)
@Observable class LiveTunerModel {
    var cents: Float = 0
    var isListening = false
    // No @Published needed — all stored properties are observed by default
}

// In a view — no property wrapper needed for passed-in model
struct TunerView: View {
    var model: LiveTunerModel   // NOT @ObservedObject

    var body: some View {
        Text(model.cents.formatted())
    }
}

// Owned by the view itself
struct RootView: View {
    @State private var model = LiveTunerModel()
}

// Injected via environment
struct RootView: View {
    @State private var model = LiveTunerModel()
    var body: some View {
        ContentView().environment(model)
    }
}

struct ContentView: View {
    @Environment(LiveTunerModel.self) private var model
}
```

## App Structure

```swift
@main
struct LUMAApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        // Menu bar extras, document groups, etc.
        #endif
    }
}
```

## Toolbar Differences

```swift
.toolbar {
    // Use ToolbarItemGroup with placement that adapts per platform
    ToolbarItemGroup(placement: .primaryAction) {
        Button("Record") { … }
    }

    #if os(macOS)
    ToolbarItemGroup(placement: .navigation) {
        BackButton()
    }
    #endif
}
// macOS unified toolbar style (title bar + toolbar merged)
.windowToolbarStyle(.unified)   // applied to WindowGroup in App body
```

## Keyboard Shortcuts (Mac)

```swift
Button("Start Tuning") { model.start() }
    .keyboardShortcut("r", modifiers: .command)

// Add app-level menu commands
.commands {
    CommandGroup(replacing: .newItem) { }  // remove New menu item
    CommandMenu("Tuner") {
        Button("Start") { … }.keyboardShortcut("r", modifiers: .command)
    }
}
```

## Adaptive Layout

```swift
struct ContentView: View {
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        if sizeClass == .compact {
            PhoneLayout()
        } else {
            PadMacLayout()
        }
    }
}

// GeometryReader for fine-grained adaptation
GeometryReader { proxy in
    let isWide = proxy.size.width > 600
    // ...
}
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using `@ObservedObject` with new `@Observable` types | Use plain `var` (passed in) or `@State` (owned); `@ObservedObject` still works but is legacy |
| `NavigationView` | Deprecated — use `NavigationStack` or `NavigationSplitView` |
| Mac-only API without `#if os(macOS)` | Fails to compile on iOS |
| `.sheet` with `isPresented` on Mac without window size | Set `.frame(minWidth:minHeight:)` on sheet content |
| Forgetting `@Environment(\.openWindow)` for multi-window | Mac supports multiple windows; use `openWindow(id:)` |

## Minimum OS Versions (LUMA)

LUMA targets iOS 17 / macOS 14 — `@Observable` and `NavigationSplitView` are fully available; no `#available` guards needed for those APIs.
