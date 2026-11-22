// Quick Settings page: toggle tiles for the switches the earbuds answered, the voice
// prompt language and device info. Dual Connection has its own sub-page.
// Layout follows nothing-x-mac.

import PeatsKit
import SwiftUI

struct QuickSettingsView: View {
    @EnvironmentObject var device: DeviceController
    @EnvironmentObject var nav: PanelNavigation

    private var state: DeviceState { device.state }

    var body: some View {
        VStack(spacing: 0) {
            SubpageHeader(title: "Quick Settings", back: .main)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                toggleTile(.gameMode, "Game Mode", "gamecontroller")
                toggleTile(.lightEffect, "Light Effect", "lightbulb")
                toggleTile(.touchLock, "Lock Touch", "hand.raised")
                toggleTile(.dynamicEq, "Dynamic EQ", "waveform")
                toggleTile(.movieMode, "Movie Mode", "film")
                panoramicTile
                dualTile
            }
            .padding(12)

            if let language = state.values[.voiceLanguage] {
                PanelSeparator()
                HStack(spacing: 10) {
                    Image(systemName: "globe").font(.system(size: 14)).foregroundStyle(Theme.secondaryLabel)
                    Text("Voice Prompts").font(.system(size: 13))
                    Spacer()
                    Picker("Voice prompt language", selection: Binding(
                        get: { language },
                        set: { device.set(.voiceLanguage, $0) })) {
                        ForEach(VoiceLanguage.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 120)
                }
                .padding(.horizontal, Theme.inset)
                .frame(height: 40)
            }

            PanelSeparator()
            DeviceInfo()
        }
    }

    // MARK: Tiles

    @ViewBuilder
    private func toggleTile(_ feature: Feature, _ name: String, _ symbol: String) -> some View {
        if let raw = state.values[feature] {
            let on = raw == 1
            QuickTile(symbol: symbol, name: name, detail: on ? "On" : "Off", on: on) {
                device.set(feature, on ? 0 : 1)
            }
        }
    }

    /// Cycles Normal → Music → Movie → Normal.
    @ViewBuilder
    private var panoramicTile: some View {
        if let raw = state.values[.panoramic] {
            let mode = PanoramicMode(rawValue: raw) ?? .normal
            QuickTile(symbol: "dot.radiowaves.left.and.right", name: "Panoramic Sound", detail: mode.label,
                      on: mode != .normal) {
                let next = (raw + 1) % PanoramicMode.allCases.count
                device.set(.panoramic, next)
            }
        }
    }

    @ViewBuilder
    private var dualTile: some View {
        if let raw = state.values[.multipoint] {
            let on = raw == 1
            QuickTile(symbol: "laptopcomputer.and.iphone", name: "Dual Connection", detail: on ? "On" : "Off",
                      on: on, onChevron: on ? { nav.page = .dual } : nil) {
                device.set(.multipoint, on ? 0 : 1)
            }
        }
    }
}

/// Control Center style tile (76 pt): icon disc, name and state. Tiles with a
/// sub-page show a chevron in the corner that opens it; the body toggles.
struct QuickTile: View {
    let symbol: String
    let name: String
    let detail: String
    var on = false
    var pending = false
    var onChevron: (() -> Void)?
    let action: () -> Void
    @Environment(\.accentFill) private var accentFill
    @StateObject private var hovering = Local(false)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack {
                        Circle().fill(on ? accentFill : Theme.controlFillStrong)
                        Image(systemName: symbol)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(on ? Color.white : Theme.label)
                    }
                    .frame(width: 26, height: 26)
                    Spacer(minLength: 6)
                    Text(name).font(.system(size: 12, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(detail).font(.system(size: 11)).foregroundStyle(Theme.secondaryLabel)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 76, maxHeight: 76, alignment: .leading)
                .background(GlassShape(radius: 14, tint: on ? accentFill : nil, tintOpacity: 0.22,
                                       strong: hovering.value, shadow: true))
                .opacity(pending ? 0.5 : 1)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(name), \(detail)")

            if pending {
                PendingSpinner(size: 12).padding(10)
            } else if let onChevron {
                Button(action: onChevron) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.secondaryLabel)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(2)
                .help("More \(name) options")
                .accessibilityLabel("\(name) options")
            }
        }
        .onHover { hovering.value = $0 }
    }
}

// MARK: - Dual Connection

struct DualConnectionView: View {
    @EnvironmentObject var device: DeviceController

    var body: some View {
        let on = device.state.values[.multipoint] == 1
        let phones = device.state.phones
        let connected = phones.filter(\.isConnected).count
        VStack(spacing: 0) {
            SubpageHeader(title: "Dual Connection") {
                Toggle("Dual Connection", isOn: Binding(get: { on },
                                                        set: { device.set(.multipoint, $0 ? 1 : 0) }))
                    .toggleStyle(.switch).controlSize(.mini).labelsHidden()
            }

            if on {
                SectionCaption("Devices", trailing: "\(connected) connected")
                    .padding(.top, 12)
                VStack(spacing: 0) {
                    ForEach(phones) { phone in
                        DualDeviceRow(phone: phone, full: connected >= 2)
                    }
                }
                if phones.isEmpty {
                    FooterNote("No device list yet. If this stays empty, this T3 Pro firmware doesn't report its remembered devices.")
                        .padding(.bottom, 8)
                }
                TipBox(text: "Up to two devices at once. Disconnect one to connect another. The device list is experimental on the T3 Pro.")
                    .padding(Theme.inset)
            } else {
                FooterNote("Turn on Dual Connection to keep the earbuds connected to two devices at once.")
                    .padding(.vertical, 12)
            }
        }
        .onAppear { device.loadPhones() }
    }
}

private struct DualDeviceRow: View {
    let phone: KnownPhone
    let full: Bool
    @EnvironmentObject var controller: DeviceController
    @Environment(\.accent) private var accent

    var body: some View {
        let busy = controller.phoneBusy == phone.addressText
        let otherBusy = controller.phoneBusy != nil && !busy
        let isSelf = controller.hostAddress == phone.addressText
        HStack(spacing: 10) {
            Image(systemName: isSelf ? "laptopcomputer" : Self.symbol(for: phone.name))
                .font(.system(size: 13))
                .frame(width: 26, height: 26)
                .background(GlassShape(radius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text(isSelf ? "This Mac" : phone.name.isEmpty ? "Unknown device" : phone.name)
                    .font(.system(size: 13)).lineLimit(1)
                HStack(spacing: 4) {
                    if phone.isConnected && !busy { Circle().fill(accent).frame(width: 5, height: 5) }
                    Text(status(busy: busy)).font(.system(size: 11)).foregroundStyle(Theme.secondaryLabel)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if busy {
                PendingSpinner(size: 12)
            } else if !isSelf {
                // This Mac can't drop itself: that would cut the control channel too.
                Button(phone.isConnected ? "Disconnect" : "Connect") {
                    controller.setPhone(phone, connect: !phone.isConnected)
                }
                .buttonStyle(PanelButtonStyle())
                .disabled(otherBusy || (!phone.isConnected && full))
            }
        }
        .padding(.horizontal, Theme.inset)
        .frame(height: 44)
    }

    private func status(busy: Bool) -> String {
        if busy { return phone.isConnected ? "Disconnecting…" : "Connecting…" }
        return phone.isConnected ? "Connected" : "Remembered"
    }

    /// The earbuds only report names, so guess an icon from the name.
    static func symbol(for name: String) -> String {
        let rules: [(String, String)] = [
            (#"iphone|phone|pixel|galaxy|oneplus|redmi|xiaomi|android"#, "iphone"),
            (#"ipad|tablet|\btab\b"#, "ipad"),
            (#"watch"#, "applewatch"),
            (#"\btv\b|television|bravia"#, "tv"),
            (#"imac|desktop|\bpc\b|studio"#, "desktopcomputer"),
            (#"mac|book|laptop|thinkpad|surface|notebook"#, "laptopcomputer"),
        ]
        for (pattern, symbol) in rules
        where name.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
            return symbol
        }
        return "antenna.radiowaves.left.and.right"
    }
}

// MARK: - Device info

private struct DeviceInfo: View {
    @EnvironmentObject var device: DeviceController

    var body: some View {
        let state = device.state
        VStack(spacing: 6) {
            SectionCaption("Device").padding(.horizontal, -Theme.inset).padding(.bottom, -2)
            row("Model", state.model.verified ? state.model.displayName : (state.name ?? state.model.displayName))
            row("Firmware", firmware(state.firmware))
            if let address = state.address, !address.isEmpty {
                row("Bluetooth", address.uppercased().replacingOccurrences(of: "-", with: ":"))
            }
        }
        .padding(.horizontal, Theme.inset)
        .padding(.top, 12)
        .padding(.bottom, Theme.inset)
    }

    private func firmware(_ text: String?) -> String? {
        guard let text else { return nil }
        return ModelInfo.parse(firmware: text).version ?? text
    }

    private func row(_ label: String, _ value: String?) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.secondaryLabel)
            Spacer()
            Text(value ?? "—")
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}
