// Design tokens from the "Dot-matrix bold" design: colors (light/dark),
// radii and type sizes, plus the accent that follows the user's choice of
// brand red or the system accent color.

import AppKit
import SwiftUI

enum Theme {
    // MARK: Colors

    static let brandRed = dynamic(light: NSColor(hex: 0xD92D20), dark: NSColor(hex: 0xFF5A4D))
    /// Primary button fill: white text stays readable in both modes.
    static let brandRedFill = Color(nsColor: NSColor(hex: 0xD92D20))

    static let label = dynamic(light: NSColor(hex: 0x1D1D1F), dark: NSColor(hex: 0xF5F5F7))
    static let secondaryLabel = dynamic(light: NSColor(hex: 0x636366), dark: NSColor(hex: 0xA1A1A6))
    static let tertiary = dynamic(light: .black.withAlphaComponent(0.28), dark: .white.withAlphaComponent(0.30))
    static let dotOff = dynamic(light: .black.withAlphaComponent(0.10), dark: .white.withAlphaComponent(0.13))
    static let separator = dynamic(light: .black.withAlphaComponent(0.10), dark: .white.withAlphaComponent(0.10))
    static let controlFill = dynamic(light: .black.withAlphaComponent(0.05), dark: .white.withAlphaComponent(0.07))
    static let controlFillStrong = dynamic(light: .black.withAlphaComponent(0.09), dark: .white.withAlphaComponent(0.12))
    static let selectedSegment = dynamic(light: .white, dark: .white.withAlphaComponent(0.22))
    static let segmentShadow = dynamic(light: .black.withAlphaComponent(0.22), dark: .black.withAlphaComponent(0.40))
    static let trackOff = dynamic(light: .black.withAlphaComponent(0.12), dark: .white.withAlphaComponent(0.16))

    // MARK: Metrics

    static let panelWidth: CGFloat = 300
    static let inset: CGFloat = 14

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
                .map { $0 == .darkAqua || $0 == .vibrantDark } == true ? dark : light
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

// MARK: - Accent

/// Brand red by default; the system accent color when the user turns that on.
private struct AccentKey: EnvironmentKey {
    static let defaultValue = Theme.brandRed
}

private struct AccentFillKey: EnvironmentKey {
    static let defaultValue = Theme.brandRedFill
}

extension EnvironmentValues {
    var accent: Color {
        get { self[AccentKey.self] }
        set { self[AccentKey.self] = newValue }
    }

    /// Fill for primary buttons and "on" tile discs (white content on top).
    var accentFill: Color {
        get { self[AccentFillKey.self] }
        set { self[AccentFillKey.self] = newValue }
    }
}

extension View {
    func panelAccent(system: Bool) -> some View {
        environment(\.accent, system ? Color.accentColor : Theme.brandRed)
            .environment(\.accentFill, system ? Color.accentColor : Theme.brandRedFill)
            .tint(system ? Color.accentColor : Theme.brandRed)
    }
}
