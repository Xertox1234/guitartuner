import SwiftUI

/// Low-emphasis edge-chrome button style (`.edge-btn` / `.tone` in
/// `ds-components.css`): a dim mono-label pill that brightens to `ink` (or an
/// accent) when active. Used by `InputSource`, `ToneToggle`, and friends.
public struct EdgeButtonStyle: ButtonStyle {
    var active: Bool
    var activeColor: Color

    public init(active: Bool = false, activeColor: Color = .lumaInk) {
        self.active = active
        self.activeColor = activeColor
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LumaFont.mono(10.5))
            .lumaTracking(Tracking.chip, size: 10.5)
            .textCase(.uppercase)
            .foregroundStyle(active ? activeColor : Color.lumaDim)
            .frame(height: 30)
            .padding(.horizontal, 11)
            .background(active ? activeColor.opacity(0.12) : Color.lumaSurface.opacity(0.55), in: Capsule())
            .overlay(
                Capsule().stroke(active ? activeColor.opacity(0.5) : Color.lumaLine2, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Capsule())
    }
}

/// A round 30×30 icon button for the top chrome (`.edge-icon`).
public struct EdgeIconButton: View {
    let systemImage: String
    let action: () -> Void
    var accessibilityLabel: String

    public init(systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16))
                .foregroundStyle(Color.lumaDim)
                .frame(width: 30, height: 30)
                .background(Color.lumaSurface.opacity(0.55), in: Circle())
                .overlay(Circle().stroke(Color.lumaLine2, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// The settings gear (`SettingsBtn`).
public struct SettingsButton: View {
    var action: () -> Void
    public init(action: @escaping () -> Void = {}) { self.action = action }
    public var body: some View {
        EdgeIconButton(systemImage: "gearshape", accessibilityLabel: "Settings", action: action)
    }
}

#if DEBUG
#Preview("Edge buttons — dark") {
    HStack(spacing: Space.s4) {
        Button("DI") {}.buttonStyle(EdgeButtonStyle())
        Button("Tone") {}.buttonStyle(EdgeButtonStyle(active: true, activeColor: .lumaInTune))
        SettingsButton()
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.lumaBg)
    .preferredColorScheme(.dark)
}
#endif
