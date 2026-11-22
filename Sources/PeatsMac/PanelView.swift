// The popover: battery, noise control, switches, touch controls and the (experimental) equalizer.
// Only controls the earbuds answered a GET for are shown.

import AppKit
import PeatsKit
import SwiftUI

struct PanelView: View {
    @ObservedObject var controller: DeviceController

    private var state: DeviceState { controller.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if state.connected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) { controls }
                        .padding(16)
                }
            } else {
                disconnected
            }
            Divider()
            footer
        }
        .frame(width: 340, height: 580)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "headphones")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.connected ? state.model.displayName : "SOUNDPEATS")
                        .font(.headline)
                    Text(statusLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if state.connected {
                HStack(spacing: 8) {
                    BatteryTile(label: "Left", value: state.battery.left)
                    BatteryTile(label: "Right", value: state.battery.right)
                    BatteryTile(label: "Case", value: state.battery.chargingCase)
                }
            }
        }
        .padding(16)
    }

    private var statusLine: String {
        if state.connected { return state.name ?? "Connected" }
        if let connecting = state.connecting { return "Connecting to \(connecting)…" }
        return "Not connected"
    }

    // MARK: Connected

    @ViewBuilder private var controls: some View {
        if state.values[.noise] != nil {
            section("Noise control") {
                Picker("Noise control", selection: Binding(
                    get: { state.values[.noise] ?? -1 },
                    set: { controller.set(.noise, $0) }
                )) {
                    ForEach(NoiseMode.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }

        section("Features") {
            toggle("Game mode", "Lower latency for video and games", .gameMode)
            toggle("Dual connection", "Stay connected to two devices", .multipoint)
            if state.values[.multipoint] != nil {
                DisclosureGroup("Dual connection devices (experimental)") {
                    phonesList.padding(.top, 6)
                }
            }
            toggle("Lock touch controls", "Ignore taps on the earbuds", .touchLock)
            toggle("Light effect", nil, .lightEffect)
            toggle("Dynamic EQ", nil, .dynamicEq)
            toggle("Movie mode", nil, .movieMode)
            if let volume = state.values[.promptVolume] {
                VolumeRow(remote: volume) { controller.set(.promptVolume, $0) }
            }
            if state.values[.voiceLanguage] != nil {
                HStack {
                    Text("Voice prompt language")
                    Spacer()
                    Picker("Language", selection: Binding(
                        get: { state.values[.voiceLanguage] ?? 0 },
                        set: { controller.set(.voiceLanguage, $0) }
                    )) {
                        ForEach(VoiceLanguage.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }
            }
            if state.values[.panoramic] != nil {
                HStack {
                    Text("Panoramic sound")
                    Spacer()
                    Picker("Panoramic sound", selection: Binding(
                        get: { state.values[.panoramic] ?? 0 },
                        set: { controller.set(.panoramic, $0) }
                    )) {
                        ForEach(PanoramicMode.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }

        if !state.keys.isEmpty {
            section("Touch controls") {
                ForEach(gestureRows) { row in
                    HStack(spacing: 8) {
                        Text(row.title)
                            .frame(width: 92, alignment: .leading)
                        keyPicker(side: "L", gesture: row.left)
                        keyPicker(side: "R", gesture: row.right)
                    }
                }
            }
        }

        DisclosureGroup("Equalizer (experimental)") {
            equalizer.padding(.top, 8)
        }

        if !state.model.verified {
            Text("This model hasn't been probed yet. You only see the controls your earbuds answered; please report what works.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private struct GestureRow: Identifiable {
        let title: String
        let left: TouchGesture
        let right: TouchGesture
        var id: String { title }
    }

    private var gestureRows: [GestureRow] {
        [
            GestureRow(title: "Tap", left: .tapLeft, right: .tapRight),
            GestureRow(title: "Double tap", left: .doubleLeft, right: .doubleRight),
            GestureRow(title: "Triple tap", left: .tripleLeft, right: .tripleRight),
            GestureRow(title: "Press & hold", left: .holdLeft, right: .holdRight),
        ]
    }

    private func keyPicker(side: String, gesture: TouchGesture) -> some View {
        HStack(spacing: 4) {
            Text(side)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(side, selection: Binding(
                get: { state.keys[gesture]?.rawValue ?? KeyAction.none.rawValue },
                set: { raw in
                    if let action = KeyAction(rawValue: raw) { controller.setKey(gesture, action) }
                }
            )) {
                ForEach(KeyAction.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .frame(maxWidth: .infinity)
    }

    private var phonesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Load devices") { controller.loadPhones() }
            if state.phones.isEmpty {
                Text("Nothing yet. If nothing appears after a few seconds, this T3 Pro firmware does not report its connected devices.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(state.phones) { phone in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(phone.name.isEmpty ? "Unknown device" : phone.name)
                        Text(phone.addressText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(phone.isConnected ? "Disconnect" : "Connect") {
                        controller.setPhone(phone, connect: !phone.isConnected)
                    }
                }
            }
        }
    }

    private var equalizer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Menu(controller.eqPreset ?? "Custom") {
                    Button("Classic (reset)") { controller.applyClassicEq() }
                    Divider()
                    ForEach(T3ProEq.presets) { preset in
                        Button(preset.name) { controller.applyPreset(preset) }
                    }
                }
                .fixedSize()
                Spacer()
            }
            ForEach(Array(T3ProEq.userHz.enumerated()), id: \.offset) { index, hz in
                HStack(spacing: 8) {
                    Text(hz >= 1000 ? "\(hz / 1000) kHz" : "\(hz) Hz")
                        .font(.caption.monospacedDigit())
                        .frame(width: 52, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { Double(controller.eqGains[index]) },
                            set: { controller.setEqGain(at: index, to: Int($0.rounded())) }
                        ),
                        in: Double(T3ProEq.userRange.lowerBound)...Double(T3ProEq.userRange.upperBound),
                        step: 1
                    )
                    Text("\(controller.eqGains[index]) dB")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
            Text("The earbuds can't report their EQ, so this shows what was last sent. Not yet verified on a T3 Pro.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Disconnected

    private var disconnected: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "headphones")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(state.connecting != nil ? "Connecting…" : "No SoundPEATS earbuds connected")
                .font(.headline)
            Text("Connect your earbuds in macOS Bluetooth settings first. Close the PeatsAudio app on your phone too: only one app can hold the control channel.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Open Bluetooth Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Bluetooth") {
                    NSWorkspace.shared.open(url)
                }
            }
            if !controller.candidates.isEmpty && state.connecting == nil {
                Divider().padding(.horizontal, 24)
                Text("Not detected automatically? Pick your earbuds:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(controller.candidates) { device in
                    Button(device.name) { controller.choose(device) }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear { controller.refreshCandidates() }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Text(firmwareLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.link)
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: Helpers

    private var firmwareLabel: String {
        guard let firmware = state.firmware else { return "" }
        if let version = ModelInfo.parse(firmware: firmware).version { return "Firmware \(version)" }
        return firmware
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    @ViewBuilder private func toggle(_ title: String, _ detail: String?, _ feature: Feature) -> some View {
        if state.values[feature] != nil {
            Toggle(isOn: Binding(
                get: { state.values[feature] == 1 },
                set: { controller.set(feature, $0 ? 1 : 0) }
            )) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                    if let detail {
                        Text(detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .toggleStyle(.switch)
        }
    }
}

private struct BatteryTile: View {
    let label: String
    let value: Int?

    var body: some View {
        VStack(spacing: 2) {
            Text(value.map { "\($0)%" } ?? "—")
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle((value ?? 100) <= 15 ? Color.red : Color.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
    }
}

/// Writes only when the drag ends, and follows the earbuds' value while idle.
private struct VolumeRow: View {
    let remote: Int
    let commit: (Int) -> Void

    @State private var value: Double = 0
    @State private var editing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Voice prompt volume")
                Spacer()
                Text("\(Int(value))")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: 0...100, step: 1) { isEditing in
                editing = isEditing
                if !isEditing { commit(Int(value)) }
            }
        }
        .onAppear { value = Double(remote) }
        .onChange(of: remote) { newValue in
            if !editing { value = Double(newValue) }
        }
    }
}
