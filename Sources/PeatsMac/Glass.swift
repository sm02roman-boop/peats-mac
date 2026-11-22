// Glassmorphism: blurred material, a bright top-left rim, soft shadow and a faint
// highlight gradient, over a panel background with coloured glows behind the glass.
// Only surfaces change; layout and behaviour are the nothing-x-mac design.

import AppKit
import SwiftUI

extension Theme {
    /// Soft white sheen across the top-left of a glass surface.
    static let glassHighlight = glassDynamic(light: NSColor.white.withAlphaComponent(0.55),
                                             dark: NSColor.white.withAlphaComponent(0.12))
    /// Rim light: bright at the top-left, fading to the bottom-right.
    static let glassBorderTop = glassDynamic(light: NSColor.white.withAlphaComponent(0.95),
                                             dark: NSColor.white.withAlphaComponent(0.38))
    static let glassBorderBottom = glassDynamic(light: NSColor.white.withAlphaComponent(0.25),
                                                dark: NSColor.white.withAlphaComponent(0.06))
    /// Glow colours behind the panel (the accent red is the third).
    static let glassBlue = Color(nsColor: NSColor(hex: 0x4F6BFF))
    static let glassTeal = Color(nsColor: NSColor(hex: 0x2EC4B6))

    private static func glassDynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
                .map { $0 == .darkAqua || $0 == .vibrantDark } == true ? dark : light
        })
    }
}

/// A glass surface to use as a `.background(...)`.
struct GlassShape: View {
    var radius: CGFloat = 10
    /// Colour washed over the glass (an "on" tile, a primary button).
    var tint: Color?
    var tintOpacity: Double = 0.30
    /// Brighter glass for raised or hovered controls.
    var strong = false
    var shadow = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            shape.fill(.ultraThinMaterial)
            if let tint {
                shape.fill(tint.opacity(tintOpacity))
            }
            shape.fill(LinearGradient(colors: [Theme.glassHighlight, Color.clear],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
            if strong {
                shape.fill(Color.white.opacity(0.08))
            }
            shape.strokeBorder(LinearGradient(colors: [Theme.glassBorderTop, Theme.glassBorderBottom],
                                              startPoint: .topLeading, endPoint: .bottomTrailing),
                               lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(shadow ? 0.20 : 0), radius: shadow ? 8 : 0, x: 0, y: shadow ? 3 : 0)
    }
}

/// The panel's own background: frosted glass with soft coloured glows so the glass has something to refract.
struct GlassBackground: View {
    @Environment(\.accent) private var accent

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            GeometryReader { geo in
                Circle().fill(accent.opacity(0.42))
                    .frame(width: 220, height: 220).blur(radius: 60)
                    .position(x: 30, y: 24)
                Circle().fill(Theme.glassBlue.opacity(0.36))
                    .frame(width: 240, height: 240).blur(radius: 70)
                    .position(x: geo.size.width - 10, y: geo.size.height * 0.55)
                Circle().fill(Theme.glassTeal.opacity(0.22))
                    .frame(width: 180, height: 180).blur(radius: 60)
                    .position(x: 30, y: geo.size.height - 10)
            }
            .clipped()
            LinearGradient(colors: [Color.white.opacity(0.07), Color.clear],
                           startPoint: .top, endPoint: .center)
        }
        .allowsHitTesting(false)
    }
}
