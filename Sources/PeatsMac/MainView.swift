// Main page: header, dot-matrix battery cells, noise control and prompt volume.
// Before a connection it shows the "not connected" guide. Layout follows nothing-x-mac.

import PeatsKit
import SwiftUI

struct MainView: View {
    @EnvironmentObject var device: DeviceController
    @EnvironmentObject var nav: PanelNavigation

    private var state: DeviceState { device.state }

    var body: some View {
        VStack(spacing: 0) {
            MainHeader()
            PanelSeparator()
            if state.connected {
                BatteryCells()
                PanelSeparator()
                if state.values[.noise] != nil {
                    NoiseControlSection()
                }
                if state.values[.promptVolume] != nil {
                    PanelSeparator()
                    PromptVolumeSection()
                }
            } else if state.connecting != nil {
                ConnectingSkeleton()
            } else {
                NotConnectedView()
            }
        }
    }
}

// MARK: - Header

private struct MainHeader: View {
    @EnvironmentObject var device: DeviceController
    @EnvironmentObject var nav: PanelNavigation

    var body: some View {
        let state = device.state
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                HStack(spacing: 5) {
                    if state.connected {
                        Circle().fill(Theme.label).frame(width: 6, height: 6)
                    } else if state.connecting != nil {
                        PendingSpinner(size: 9)
                    }
                    Text(status).font(.system(size: 11)).foregroundStyle(Theme.secondaryLabel)
                }
            }
            Spacer(minLength: 0)
            // Nothing to configure until the earbuds are connected; Quit stays in the right-click menu.
            if state.connected {
                HeaderIconButton(symbol: "slider.vertical.3", help: "Equalizer") { nav.page = .equalizer }
                HeaderIconButton(symbol: "square.grid.2x2", help: "Quick Settings") { nav.page = .quickSettings }
                HeaderIconButton(symbol: "power", help: "Quit PeatsMac") { NSApp.terminate(nil) }
            }
        }
        .padding(.leading, Theme.inset)
        .padding(.trailing, 10)
        .frame(height: 50)
    }

    private var title: String {
        let state = device.state
        if state.connected { return state.name ?? "Earbuds" }
        return state.connecting ?? "PeatsMac"
    }

    private var status: String {
        let state = device.state
        if state.connected { return "Connected" }
        return state.connecting != nil ? "Connecting…" : "Not connected"
    }
}

// MARK: - Battery

private struct BatteryCells: View {
    @EnvironmentObject var device: DeviceController
    @EnvironmentObject var nav: PanelNavigation

    var body: some View {
        let battery = device.state.battery
        let gestures = !device.state.keys.isEmpty
        HStack(spacing: 6) {
            BatteryCell(icon: .bud(mirrored: true), label: "Left", level: battery.left,
                        action: gestures ? { nav.page = .controls(.left) } : nil)
            BatteryCell(icon: .bud(mirrored: false), label: "Right", level: battery.right,
                        action: gestures ? { nav.page = .controls(.right) } : nil)
            BatteryCell(icon: .symbol("earbuds.case"), label: "Case", level: battery.chargingCase, action: nil)
        }
        .padding(8)
    }
}

enum CellIcon {
    case bud(mirrored: Bool)
    case symbol(String)
}

/// One battery column: icon + label, 5×7 dot numerals and a 10-dot level row.
/// 20% or less turns the numerals and dots accent.
struct BatteryCell: View {
    let icon: CellIcon
    let label: String
    let level: Int?
    let action: (() -> Void)?
    var skeleton = false
    @Environment(\.accent) private var accent
    @StateObject private var hovering = Local(false)

    var body: some View {
        let low = level.map { $0 <= 20 } ?? false
        Button { action?() } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 4) {
                    switch icon {
                    case .bud(let mirrored):
                        DotBudView(look: skeleton ? .disconnected : .connected, size: 12,
                                   mirrored: mirrored, color: Theme.secondaryLabel)
                    case .symbol(let name):
                        Image(systemName: name).font(.system(size: 10)).foregroundStyle(Theme.secondaryLabel)
                            .frame(width: 12, height: 12)
                    }
                    Text(label).font(.system(size: 11, weight: .medium))
                    Spacer(minLength: 0)
                }
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    DotDigits(text: level.map { "\($0)" } ?? "--",
                              on: level == nil ? Theme.tertiary : low ? accent : Theme.label)
                    Text("%").font(.system(size: 11)).foregroundStyle(Theme.secondaryLabel)
                }
                DotMeter(count: 10, lit: level.map { Int((Double($0) / 10).rounded(.up)) } ?? 0,
                         on: low ? accent : Theme.label)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GlassShape(radius: 12, strong: action != nil && hovering.value, shadow: true))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(action != nil)
        .help(action != nil ? "\(label) earbud controls" : "")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(level.map { "\($0) percent" } ?? "unknown")")
        .onHover { hovering.value = $0 }
    }
}

// MARK: - Noise control

private struct NoiseControlSection: View {
    @EnvironmentObject var device: DeviceController

    var body: some View {
        let selected = device.state.values[.noise].flatMap { NoiseMode(rawValue: $0) }
        let modes: [SegmentItem<NoiseMode>] = [
            SegmentItem(id: .anc, label: "ANC", symbol: "circle.inset.filled"),
            SegmentItem(id: .transparency, label: "Transparency", symbol: "circle.dashed"),
            SegmentItem(id: .off, label: "Off", symbol: "circle.slash"),
        ]
        VStack(spacing: 0) {
            SectionCaption("Noise Control").padding(.top, 12)
            DotSegmented(items: modes, selection: selected) { mode in
                device.set(.noise, mode.rawValue)
            }
            .padding(.horizontal, Theme.inset)
        }
        .padding(.bottom, 12)
    }
}

// MARK: - Prompt volume

private struct PromptVolumeSection: View {
    @EnvironmentObject var device: DeviceController
    @StateObject private var drag = Local<Int?>(nil)

    var body: some View {
        let remote = device.state.values[.promptVolume] ?? 0
        let shown = drag.value ?? remote
        VStack(spacing: 10) {
            HStack {
                Text("Prompt Volume").font(.system(size: 13))
                Spacer()
            }
            HStack {
                LevelSlider(value: shown,
                            onDrag: { drag.value = $0 },
                            onCommit: { drag.value = nil; device.set(.promptVolume, $0) })
                    .frame(width: 200)
                Spacer()
                Text("\(shown)%").font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(Theme.secondaryLabel)
            }
        }
        .padding(.horizontal, Theme.inset)
        .padding(.vertical, 14)
    }
}

/// Slider for 0…100: 4 pt track, accent fill, 16 pt white knob. Writes when the drag ends.
struct LevelSlider: View {
    let value: Int
    let onDrag: (Int) -> Void
    let onCommit: (Int) -> Void
    @Environment(\.accent) private var accent

    var body: some View {
        GeometryReader { geo in
            let knob: CGFloat = 16
            let usable = geo.size.width - knob
            let x = knob / 2 + CGFloat(value) / 100 * usable
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.trackOff).frame(height: 4)
                Capsule().fill(accent).frame(width: x, height: 4)
                Circle().fill(Color.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                    .frame(width: knob, height: knob)
                    .position(x: x, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { drag in onDrag(Self.level(drag.location.x, knob: knob, usable: usable)) }
                .onEnded { drag in onCommit(Self.level(drag.location.x, knob: knob, usable: usable)) })
        }
        .frame(height: 24)
        .accessibilityElement()
        .accessibilityLabel("Prompt volume")
        .accessibilityValue("\(value) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onCommit(min(value + 5, 100))
            case .decrement: onCommit(max(value - 5, 0))
            @unknown default: break
            }
        }
    }

    private static func level(_ x: CGFloat, knob: CGFloat, usable: CGFloat) -> Int {
        guard usable > 0 else { return 0 }
        let raw = Int(((x - knob / 2) / usable * 100).rounded())
        return min(max(raw, 0), 100)
    }
}

// MARK: - Before a connection

private struct ConnectingSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                BatteryCell(icon: .bud(mirrored: true), label: "Left", level: nil, action: nil, skeleton: true)
                BatteryCell(icon: .bud(mirrored: false), label: "Right", level: nil, action: nil, skeleton: true)
                BatteryCell(icon: .symbol("earbuds.case"), label: "Case", level: nil, action: nil, skeleton: true)
            }
            .padding(8)
            PanelSeparator()
            VStack(spacing: 0) {
                SectionCaption("Noise Control").padding(.top, 12)
                DotSegmented(items: [SegmentItem(id: 0, label: "ANC", symbol: "circle.inset.filled"),
                                     SegmentItem(id: 1, label: "Transparency", symbol: "circle.dashed"),
                                     SegmentItem(id: 2, label: "Off", symbol: "circle.slash")],
                             selection: nil) { _ in }
                    .padding(.horizontal, Theme.inset)
                    .padding(.bottom, 12)
            }
            .opacity(0.4)
            FooterNote("If this takes long, close the PeatsAudio app on your phone. The earbuds accept one controller at a time.")
                .padding(.bottom, 12)
        }
        .allowsHitTesting(false)
    }
}

private struct NotConnectedView: View {
    @EnvironmentObject var device: DeviceController

    var body: some View {
        VStack(spacing: 0) {
            DotBudView(look: .disconnected, size: 44, color: Theme.label)
                .padding(.top, 18)
            Text("No earbuds connected")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 12)
            Text("Connect your SoundPEATS earbuds in System Settings › Bluetooth. They show up here once connected.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryLabel)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, 6)

            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("Open Bluetooth Settings").frame(maxWidth: .infinity)
            }
            .buttonStyle(PanelButtonStyle())
            .padding(.horizontal, Theme.inset)
            .padding(.top, 14)

            if !device.candidates.isEmpty {
                SectionCaption("Not detected? Pick your earbuds").padding(.top, 16)
                VStack(spacing: 4) {
                    ForEach(device.candidates) { candidate in
                        CandidateRow(candidate: candidate)
                    }
                }
                .padding(.horizontal, Theme.inset)
            }

            TipBox(bold: "Phone app open?",
                   text: "Close PeatsAudio on your phone. The earbuds accept only one controller at a time.")
                .padding(.horizontal, Theme.inset)
                .padding(.top, 12)
                .padding(.bottom, Theme.inset)
        }
        .onAppear { device.refreshCandidates() }
    }
}

private struct CandidateRow: View {
    let candidate: BluetoothTransport.PairedDevice
    @EnvironmentObject var device: DeviceController

    var body: some View {
        HStack(spacing: 10) {
            DotBudView(look: .disconnected, size: 14, color: Theme.secondaryLabel)
            Text(candidate.name).font(.system(size: 13)).lineLimit(1)
            Spacer(minLength: 4)
            Button("Use") { device.choose(candidate) }
                .buttonStyle(PanelButtonStyle())
                .controlSize(.small)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(height: 40)
        .background(GlassShape(radius: 10))
    }
}
