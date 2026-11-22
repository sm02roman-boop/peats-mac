// Dot-matrix pieces drawn from circles only: the "Dot Bud" mark (menu bar, app
// icon, fit test), 5×7 numerals for battery levels, and dot meters.

import AppKit
import SwiftUI

// MARK: - Dot Bud mark

/// A ring of 8 dots plus a 3-dot stem, tracing an earbud in side view, with a
/// solid driver dot in the centre. Every state uses the same dots and only
/// changes their opacity, so the menu bar item never jumps.
enum DotBud {
    enum Look: Equatable {
        case disconnected, connecting, connected, low
    }

    struct Dot {
        var center: CGPoint
        var diameter: CGFloat
        var alpha: CGFloat
        var isDriver = false
    }

    /// On an 18×18 canvas, y pointing down.
    static let canvas: CGFloat = 18
    static let ringCenter = CGPoint(x: 7.5, y: 7.0)
    static let ringRadius: CGFloat = 5.2
    static let ringDot: CGFloat = 2.2
    static let driverDot: CGFloat = 4.0
    static let stemX: CGFloat = 12.7
    static let stemY: [CGFloat] = [10.3, 13.5, 16.7]

    static func dots(_ look: Look) -> [Dot] {
        var dots: [Dot] = []
        for i in 0..<8 {
            // Clockwise from 12 o'clock.
            let angle = CGFloat(i) * .pi / 4
            let center = CGPoint(x: ringCenter.x + ringRadius * sin(angle),
                                 y: ringCenter.y - ringRadius * cos(angle))
            let alpha: CGFloat
            switch look {
            case .disconnected: alpha = 0.35
            case .connecting: alpha = i <= 2 ? 1 : 0.3
            case .connected: alpha = 1
            case .low: alpha = (i == 4 || i == 5) ? 1 : 0.3
            }
            dots.append(Dot(center: center, diameter: ringDot, alpha: alpha))
        }
        let stemAlpha: CGFloat = {
            switch look {
            case .disconnected: return 0.35
            case .connecting: return 0.3
            case .connected, .low: return 1
            }
        }()
        for y in stemY {
            dots.append(Dot(center: CGPoint(x: stemX, y: y), diameter: ringDot, alpha: stemAlpha))
        }
        switch look {
        case .disconnected: break
        case .connecting: dots.append(Dot(center: ringCenter, diameter: driverDot, alpha: 0.3, isDriver: true))
        case .connected, .low: dots.append(Dot(center: ringCenter, diameter: driverDot, alpha: 1, isDriver: true))
        }
        return dots
    }

    /// Menu bar template image (black + alpha; macOS tints it).
    static func templateImage(_ look: Look) -> NSImage {
        let image = NSImage(size: NSSize(width: canvas, height: canvas), flipped: true) { _ in
            for dot in dots(look) {
                NSColor.black.withAlphaComponent(dot.alpha).setFill()
                NSBezierPath(ovalIn: rect(dot, scale: 1)).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "PeatsMac"
        return image
    }

    static func rect(_ dot: Dot, scale: CGFloat, offset: CGPoint = .zero) -> CGRect {
        CGRect(x: offset.x + (dot.center.x - dot.diameter / 2) * scale,
               y: offset.y + (dot.center.y - dot.diameter / 2) * scale,
               width: dot.diameter * scale, height: dot.diameter * scale)
    }
}

/// The Dot Bud mark as a SwiftUI view. `mirrored` flips it for the left bud.
struct DotBudView: View {
    var look: DotBud.Look = .connected
    var size: CGFloat = 18
    var mirrored = false
    var color: Color = Theme.label
    /// Colour for the centre dot (defaults to `color`).
    var driver: Color?

    var body: some View {
        Canvas { ctx, canvasSize in
            let scale = canvasSize.width / DotBud.canvas
            for dot in DotBud.dots(look) {
                var r = DotBud.rect(dot, scale: scale)
                if mirrored { r.origin.x = canvasSize.width - r.maxX }
                let fill = dot.isDriver ? (driver ?? color) : color
                ctx.fill(Path(ellipseIn: r), with: .color(fill.opacity(dot.alpha)))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - 5×7 numerals

enum Dot57 {
    /// Each glyph is 7 rows of 5 bits, most significant bit = leftmost column.
    static let rows: [Character: [UInt8]] = [
        "0": [0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110],
        "1": [0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110],
        "2": [0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0b01000, 0b11111],
        "3": [0b11111, 0b00010, 0b00100, 0b00010, 0b00001, 0b10001, 0b01110],
        "4": [0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010],
        "5": [0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110],
        "6": [0b00110, 0b01000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110],
        "7": [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000],
        "8": [0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110],
        "9": [0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00010, 0b01100],
        "%": [0b11001, 0b11010, 0b00010, 0b00100, 0b01000, 0b01011, 0b10011],
        "-": [0b00000, 0b00000, 0b00000, 0b01110, 0b00000, 0b00000, 0b00000],
    ]
}

/// Battery-style numerals on a 5×7 dot grid, with faint unlit dots like a
/// see-through display. Pitch 2.6 is the panel's medium size.
struct DotDigits: View {
    let text: String
    var pitch: CGFloat = 2.6
    var on: Color = Theme.label
    var off: Color = Theme.dotOff

    var body: some View {
        let chars = Array(text)
        Canvas { ctx, _ in
            let d = pitch * 0.72
            var x: CGFloat = 0
            for ch in chars {
                let rows = Dot57.rows[ch] ?? []
                for row in 0..<7 {
                    let bits = row < rows.count ? rows[row] : 0
                    for col in 0..<5 {
                        let lit = bits & (1 << (4 - col)) != 0
                        let rect = CGRect(x: x + CGFloat(col) * pitch + (pitch - d) / 2,
                                          y: CGFloat(row) * pitch + (pitch - d) / 2,
                                          width: d, height: d)
                        ctx.fill(Path(ellipseIn: rect), with: .color(lit ? on : off))
                    }
                }
                x += 6 * pitch
            }
        }
        .frame(width: max(0, CGFloat(chars.count * 6 - 1) * pitch), height: 7 * pitch)
        .accessibilityLabel(text)
    }
}

/// A row of dots, the first `lit` of them filled. Used for battery levels and progress.
struct DotMeter: View {
    var count: Int
    var lit: Int
    var diameter: CGFloat = 3
    var pitch: CGFloat = 7
    var on: Color = Theme.label
    var off: Color = Theme.dotOff

    var body: some View {
        Canvas { ctx, _ in
            for i in 0..<count {
                let rect = CGRect(x: CGFloat(i) * pitch, y: 0, width: diameter, height: diameter)
                ctx.fill(Path(ellipseIn: rect), with: .color(i < lit ? on : off))
            }
        }
        .frame(width: CGFloat(max(count - 1, 0)) * pitch + diameter, height: diameter)
        .accessibilityHidden(true)
    }
}
