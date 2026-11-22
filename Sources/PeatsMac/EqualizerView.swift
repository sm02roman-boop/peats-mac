// Equalizer page: preset list and, for Custom, a frequency-response curve over eight
// band sliders (−6…+6 dB), plus custom EQs saved on this Mac. Layout follows nothing-x-mac.
// The earbuds can't report their EQ, and writes are unverified on a real T3 Pro.

import AppKit
import PeatsKit
import SwiftUI

struct EqualizerView: View {
    @EnvironmentObject var device: DeviceController

    var body: some View {
        let customSelected = device.eqPreset == nil
        VStack(spacing: 0) {
            SubpageHeader(title: "Equalizer", back: .main)

            if customSelected {
                EqCurve(gains: device.eqGains)
                    .frame(height: 84)
                    .padding(.horizontal, Theme.inset)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
            }

            VStack(spacing: 2) {
                SelectRow(label: DeviceController.classicName, selected: device.eqPreset == DeviceController.classicName) {
                    device.applyClassicEq()
                }
                ForEach(T3ProEq.presets) { preset in
                    SelectRow(label: preset.name, selected: device.eqPreset == preset.name) {
                        device.applyPreset(preset)
                    }
                }
                SelectRow(label: "Custom", selected: customSelected) {
                    device.applyCustomEq()
                }
            }
            .padding(.vertical, 8)

            if customSelected {
                PanelSeparator()
                VStack(spacing: 4) {
                    ForEach(Array(T3ProEq.userHz.enumerated()), id: \.offset) { index, hz in
                        BandSlider(name: Self.label(hz), value: device.eqGains[index]) {
                            device.setEqGain(at: index, to: $0)
                        }
                    }
                }
                .padding(.vertical, 10)
            }

            PanelSeparator()
            SavedPresets(current: customSelected ? device.eqGains : nil)

            TipBox(text: "Experimental on the T3 Pro. The earbuds can't report their EQ, so this shows what was last sent.")
                .padding(Theme.inset)
        }
    }

    static func label(_ hz: Int) -> String {
        hz >= 1000 ? "\(hz / 1000) kHz" : "\(hz) Hz"
    }
}

/// −6…+6 dB in 1 dB steps; the fill grows from the 0 dB tick.
private struct BandSlider: View {
    let name: String
    let value: Int
    let onChange: (Int) -> Void
    @Environment(\.accent) private var accent

    var body: some View {
        HStack(spacing: 10) {
            Text(name).font(.system(size: 12)).frame(width: 44, alignment: .leading)
            GeometryReader { geo in
                let knob: CGFloat = 16
                let usable = geo.size.width - knob
                let xFor = { (v: Int) in knob / 2 + CGFloat(v + 6) / 12 * usable }
                let zero = xFor(0), x = xFor(value)
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.trackOff).frame(height: 4)
                    Rectangle().fill(accent)
                        .frame(width: abs(x - zero), height: 4)
                        .offset(x: min(x, zero))
                    Rectangle().fill(Theme.tertiary).frame(width: 1, height: 10).offset(x: zero - 0.5)
                    Circle().fill(Color.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                        .frame(width: knob, height: knob)
                        .offset(x: x - knob / 2)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                    let v = Int(((drag.location.x - knob / 2) / usable * 12 - 6).rounded())
                    let clamped = min(max(v, -6), 6)
                    if clamped != value { onChange(clamped) }
                })
            }
            .frame(height: 24)
            .accessibilityElement()
            .accessibilityLabel(name)
            .accessibilityValue(Self.format(value))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: if value < 6 { onChange(value + 1) }
                case .decrement: if value > -6 { onChange(value - 1) }
                @unknown default: break
                }
            }
            Text(Self.format(value)).font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Theme.secondaryLabel).frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, Theme.inset)
    }

    static func format(_ v: Int) -> String {
        v > 0 ? "+\(v) dB" : v < 0 ? "−\(abs(v)) dB" : "0 dB"
    }
}

// MARK: - Saved presets

private struct SavedPresets: View {
    /// The current custom gains, or nil when a built-in preset is selected.
    let current: [Int]?
    @EnvironmentObject var device: DeviceController

    var body: some View {
        VStack(spacing: 2) {
            SectionCaption("Saved Presets").padding(.top, 10).padding(.bottom, -4)
            ForEach(device.savedEqs) { saved in
                HStack(spacing: 0) {
                    SelectRow(label: saved.name, detail: Self.summary(saved), selected: saved.gains == current) {
                        device.applySaved(saved)
                    }
                    Menu {
                        Button("Apply") { device.applySaved(saved) }
                        Button("Rename…") {
                            if let name = NamePrompt.ask(title: "Rename Preset", initial: saved.name) {
                                device.renameSaved(saved, to: name)
                            }
                        }
                        Divider()
                        Button("Delete") { device.deleteSaved(saved) }
                    } label: {
                        Image(systemName: "ellipsis").font(.system(size: 11))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .tint(Theme.secondaryLabel)
                    .fixedSize()
                    .padding(.trailing, Theme.inset)
                    .accessibilityLabel("\(saved.name) options")
                }
            }
            Button {
                if let name = NamePrompt.ask(title: "Save Preset", initial: "") {
                    device.saveCurrentEq(named: name)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.secondaryLabel).frame(width: 14)
                    Text("Save Current…").font(.system(size: 13))
                    Spacer()
                }
                .frame(height: 28)
            }
            .buttonStyle(HoverRowStyle())
            .disabled(current == nil)
            .help(current == nil ? "Choose Custom to save its bands" : "Save the current bands under a name")
        }
        .padding(.bottom, 8)
    }

    /// Bass / mid / treble summary of the eight gains, e.g. "B+3 M0 T−2".
    static func summary(_ eq: SavedEq) -> String {
        func f(_ v: Int) -> String { v > 0 ? "+\(v)" : v < 0 ? "−\(abs(v))" : "0" }
        func avg(_ range: Range<Int>) -> Int {
            let values = eq.gains.indices.filter { range.contains($0) }.map { eq.gains[$0] }
            guard !values.isEmpty else { return 0 }
            return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
        }
        return "B\(f(avg(0..<3))) M\(f(avg(3..<5))) T\(f(avg(5..<8)))"
    }
}

/// A small NSAlert asking for a name. Returns nil when cancelled or empty.
enum NamePrompt {
    static func ask(title: String, initial: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "Name"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = initial
        field.placeholderString = "e.g. Commute"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}

// MARK: - Curve

/// Frequency response of the eight bands on a log axis (20 Hz–20 kHz), approximated as
/// smooth bumps centred on each band.
private struct EqCurve: View {
    let gains: [Int]
    @Environment(\.accent) private var accent

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, plotH = geo.size.height - 14
            let logMin = log10(20.0), logMax = log10(20_000.0)
            let xFor = { (f: Double) in CGFloat((log10(f) - logMin) / (logMax - logMin)) * w }
            let yFor = { (db: Double) in plotH / 2 - CGFloat(max(-7, min(7, db)) / 7) * (plotH / 2) }
            let samples = (0...80).map { i -> CGPoint in
                let f = pow(10, logMin + (logMax - logMin) * Double(i) / 80)
                return CGPoint(x: xFor(f), y: yFor(Self.response(f, gains)))
            }
            let curve = Path { p in p.addLines(samples) }
            ZStack(alignment: .topLeading) {
                // ±6 dB lines and decade lines
                Path { p in
                    for db in [-6.0, 6.0] {
                        p.move(to: CGPoint(x: 0, y: yFor(db))); p.addLine(to: CGPoint(x: w, y: yFor(db)))
                    }
                    for f in [100.0, 1000, 10_000] {
                        p.move(to: CGPoint(x: xFor(f), y: 0)); p.addLine(to: CGPoint(x: xFor(f), y: plotH))
                    }
                }
                .stroke(Theme.separator, lineWidth: 1)
                Path { p in
                    p.move(to: CGPoint(x: 0, y: yFor(0))); p.addLine(to: CGPoint(x: w, y: yFor(0)))
                }
                .stroke(Theme.tertiary, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))

                Path { p in
                    p.addLines(samples)
                    p.addLine(to: CGPoint(x: w, y: yFor(0)))
                    p.addLine(to: CGPoint(x: 0, y: yFor(0)))
                    p.closeSubpath()
                }
                .fill(accent.opacity(0.12))
                curve.stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                Text("+6").font(.system(size: 9)).foregroundStyle(Theme.secondaryLabel)
                    .offset(x: 2, y: yFor(6) - 12)
                ForEach([(100.0, "100"), (1000, "1k"), (10_000, "10k")], id: \.1) { f, label in
                    Text(label).font(.system(size: 9)).foregroundStyle(Theme.secondaryLabel)
                        .offset(x: xFor(f) + 3, y: plotH + 2)
                }
            }
            .animation(.easeOut(duration: 0.15), value: gains)
        }
        .accessibilityHidden(true)
    }

    /// Sum of one smooth bump per band (width about 0.7 octave), in dB.
    static func response(_ f: Double, _ gains: [Int]) -> Double {
        var total = 0.0
        for (index, hz) in T3ProEq.userHz.enumerated() where index < gains.count {
            let octaves = log2(f / Double(hz))
            total += Double(gains[index]) * exp(-octaves * octaves / (2 * 0.7 * 0.7))
        }
        return total
    }
}
