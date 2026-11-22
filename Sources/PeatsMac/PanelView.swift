// The popover: one scrolling panel with plain native controls and the system accent colour.
// Only controls the earbuds answered a GET for are shown.

import AppKit
import PeatsKit
import SwiftUI

struct PanelView: View {
    @ObservedObject var controller: DeviceController

    @State private var showEqualizer = false
    @State private var showPhones = false

    private var state: DeviceState { controller.state }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if state.connected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) { content }
                        .padding(14)
                }
            } else {
                DisconnectedView(controller: controller)
            }
            Divider()
            footer
        }
        .frame(width: 340, height: 600)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "headphones")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(state.connected ? (state.name ?? "SOUNDPEATS") : "SOUNDPEATS")
                    .font(.headline)
                    .lineLimit(1)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
    }

    private var statusLine: String {
        if state.connected { return "Connected" }
        if let connecting = state.connecting { return "Connecting to \(connecting)…" }
        return "Not connected"
    }

    // MARK: Connected

    @ViewBuilder private var content: some View {
        card(nil) {
            HStack(spacing: 10) {
                BatteryTile(label: "Left", value: state.battery.left)
                BatteryTile(label: "Right", value: state.battery.right)
                BatteryTile(label: "Case", value: state.battery.chargingCase)
            }
        }

        if state.values[.noise] != nil {
            card("Noise control") {
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

        card("Features") {
            let rows = featureRows
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider() }
                row
            }
        }

        if !state.keys.isEmpty {
            card("Touch controls") {
                VStack(spacing: 8) {
                    HStack {
                        Spacer().frame(width: 92)
                        Text("Left").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                        Text("Right").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                    ForEach(gestureRows) { row in
                        HStack(spacing: 8) {
                            Text(row.title)
                                .frame(width: 92, alignment: .leading)
                            keyPicker(row.left)
                            keyPicker(row.right)
                        }
                    }
                }
            }
        }

        if state.values[.multipoint] == 1 {
            card(nil) {
                DisclosureGroup("Dual connection devices", isExpanded: $showPhones) { phonesList.padding(.top, 8) }
                    .onChange(of: showPhones) { open in
                        if open { controller.loadPhones() }
                    }
            }
        }

        card(nil) {
            DisclosureGroup("Equalizer", isExpanded: $showEqualizer) { equalizer.padding(.top, 8) }
        }
    }

    // MARK: Feature rows

    private var featureRows: [AnyView] {
        var rows: [AnyView] = []
        func addToggle(_ title: String, _ detail: String?, _ feature: Feature) {
            guard state.values[feature] != nil else { return }
            rows.append(AnyView(toggle(title, detail, feature)))
        }
        addToggle("Game mode", "Lower latency for video and games", .gameMode)
        addToggle("Dual connection", "Stay connected to two devices", .multipoint)
        addToggle("Lock touch controls", "Ignore taps on the earbuds", .touchLock)
        addToggle("Light effect", nil, .lightEffect)
        addToggle("Dynamic EQ", nil, .dynamicEq)
        addToggle("Movie mode", nil, .movieMode)
        if let volume = state.values[.promptVolume] {
            rows.append(AnyView(VolumeRow(remote: volume) { controller.set(.promptVolume, $0) }))
        }
        if state.values[.voiceLanguage] != nil {
            rows.append(AnyView(menuRow("Voice prompt language", .voiceLanguage, VoiceLanguage.allCases.map { ($0.label, $0.rawValue) })))
        }
        if state.values[.panoramic] != nil {
            rows.append(AnyView(menuRow("Panoramic sound", .panoramic, PanoramicMode.allCases.map { ($0.label, $0.rawValue) })))
        }
        return rows
    }

    private func toggle(_ title: String, _ detail: String?, _ feature: Feature) -> some View {
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

    private func menuRow(_ title: String, _ feature: Feature, _ options: [(String, Int)]) -> some View {
        HStack {
            Text(title)
            Spacer()
            Picker(title, selection: Binding(
                get: { state.values[feature] ?? 0 },
                set: { controller.set(feature, $0) }
            )) {
                ForEach(options, id: \.1) { Text($0.0).tag($0.1) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        }
    }

    // MARK: Touch controls

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

    private func keyPicker(_ gesture: TouchGesture) -> some View {
        Picker("", selection: Binding(
            get: { state.keys[gesture]?.rawValue ?? KeyAction.none.rawValue },
            set: { raw in
                if let action = KeyAction(rawValue: raw) { controller.setKey(gesture, action) }
            }
        )) {
            ForEach(KeyAction.allCases) { Text($0.label).tag($0.rawValue) }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }

    // MARK: Dual connection devices

    private var phonesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if state.phones.isEmpty {
                Text("No device list yet. If this stays empty, this T3 Pro firmware doesn't report its remembered devices.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(state.phones) { phone in
                let isSelf = controller.hostAddress == phone.addressText
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(isSelf ? "This Mac" : phone.name.isEmpty ? "Unknown device" : phone.name)
                        Text(phone.isConnected ? "Connected" : "Remembered")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    // This Mac can't drop itself: that would cut the control channel too.
                    if !isSelf {
                        Button(phone.isConnected ? "Disconnect" : "Connect") {
                            controller.setPhone(phone, connect: !phone.isConnected)
                        }
                        .disabled(controller.phoneBusy != nil)
                    }
                }
            }
            Button("Reload") { controller.loadPhones() }
                .font(.caption)
            Text("Experimental on the T3 Pro.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Equalizer

    private var equalizer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu(controller.eqPreset ?? "Custom") {
                Button(DeviceController.classicName) { controller.applyClassicEq() }
                Divider()
                ForEach(T3ProEq.presets) { preset in
                    Button(preset.name) { controller.applyPreset(preset) }
                }
                if !controller.savedEqs.isEmpty {
                    Divider()
                    ForEach(controller.savedEqs) { saved in
                        Button(saved.name) { controller.applySaved(saved) }
                    }
                }
                Divider()
                Button("Save current as…") {
                    if let name = NamePrompt.ask(title: "Save Preset", initial: "") {
                        controller.saveCurrentEq(named: name)
                    }
                }
                if !controller.savedEqs.isEmpty {
                    Menu("Delete saved") {
                        ForEach(controller.savedEqs) { saved in
                            Button(saved.name) { controller.deleteSaved(saved) }
                        }
                    }
                }
            }
            .fixedSize()

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
            Text("Experimental on the T3 Pro. The earbuds can't report their EQ, so this shows what was last sent.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
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
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var firmwareLabel: String {
        guard state.connected, let firmware = state.firmware else { return "" }
        if let version = ModelInfo.parse(firmware: firmware).version { return "Firmware \(version)" }
        return firmware
    }

    // MARK: Helpers

    private func card<Content: View>(_ title: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08)))
    }
}

// MARK: - Pieces

private struct BatteryTile: View {
    let label: String
    let value: Int?

    var body: some View {
        VStack(spacing: 6) {
            Text(value.map { "\($0)%" } ?? "—")
                .font(.title3.monospacedDigit().weight(.semibold))
            ProgressView(value: Double(value ?? 0), total: 100)
                .tint((value ?? 100) <= 20 ? Color.red : Color.green)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
                Text("\(Int(value))%")
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

private struct DisconnectedView: View {
    @ObservedObject var controller: DeviceController

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "headphones")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(controller.state.connecting != nil ? "Connecting…" : "No SoundPEATS earbuds connected")
                .font(.headline)
            Text("Connect your earbuds in macOS Bluetooth settings first. Close the PeatsAudio app on your phone too: only one app can hold the control channel.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Open Bluetooth Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
                    NSWorkspace.shared.open(url)
                }
            }
            if !controller.candidates.isEmpty && controller.state.connecting == nil {
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
