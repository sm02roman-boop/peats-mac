// Owns the Bluetooth channel and everything the panel shows. Every reply, asked for or
// not, updates the state: the earbuds also push the current value when it changes by
// touch, and a SET gets no reply of its own on most models (the new value comes back as
// a GET reply a moment later, so a short read-back is requested after each write).

import Combine
import Foundation
import PeatsKit

struct Battery: Equatable {
    var left: Int?
    var right: Int?
    var chargingCase: Int?
}

struct DeviceState: Equatable {
    var connected = false
    /// Earbuds the control channel is being opened to (before `connected`).
    var connecting: String?
    var name: String?
    var firmware: String?
    var model = ModelInfo.identify(firmware: nil)
    var battery = Battery()
    /// Only features the earbuds answered a GET for. A GET the firmware lacks gets no reply.
    var values: [Feature: Int] = [:]
    var keys: [TouchGesture: KeyAction] = [:]
}

final class DeviceController: ObservableObject {
    @Published private(set) var state = DeviceState()
    /// The eight user EQ gains in whole dB. The EQ is write-only on the earbuds, so this is
    /// what the app last sent, remembered across launches.
    @Published private(set) var eqGains = Array(repeating: 0, count: T3ProEq.userBands.count)
    /// Name of the last applied preset, or nil for the custom curve.
    @Published private(set) var eqPreset: String?

    private let transport = BluetoothTransport()
    private var parser = FrameParser()
    private var outbox: [[UInt8]] = []
    private var sending = false
    private var pollTimer: Timer?
    private var eqWork: DispatchWorkItem?
    private var address: String?

    /// PeatsAudio leaves 50 ms between writes and never waits for a reply.
    private static let writeSpacing: TimeInterval = 0.05

    init() {
        transport.onConnecting = { [weak self] name in self?.state.connecting = name }
        transport.onConnected = { [weak self] name, address in self?.connected(name: name, address: address) }
        transport.onDisconnected = { [weak self] in self?.disconnected() }
        transport.onData = { [weak self] bytes in self?.receive(bytes) }
    }

    func start() { transport.start() }

    func stop() {
        pollTimer?.invalidate()
        transport.stop()
    }

    // MARK: Connection

    private func connected(name: String, address: String) {
        parser.reset()
        outbox.removeAll()
        self.address = address
        state = DeviceState(connected: true, connecting: nil, name: name)
        loadEq()
        send(Request.probe)

        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.send(Request.battery)
        }
    }

    private func disconnected() {
        pollTimer?.invalidate()
        pollTimer = nil
        outbox.removeAll()
        sending = false
        eqWork?.cancel()
        state = DeviceState()
    }

    // MARK: Sending

    private func send(_ frames: [[UInt8]]) {
        outbox += frames
        drain()
    }

    private func drain() {
        guard !sending, !outbox.isEmpty, transport.isConnected else { return }
        sending = true
        let frame = outbox.removeFirst()
        Log.frame("->", frame)
        transport.write(frame)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.writeSpacing) { [weak self] in
            self?.sending = false
            self?.drain()
        }
    }

    private func readBack(_ frame: [UInt8], after delay: TimeInterval = 0.6) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.send([frame])
        }
    }

    // MARK: Receiving

    private func receive(_ bytes: [UInt8]) {
        Log.frame("<-", bytes)
        for frame in parser.push(bytes) {
            guard let update = Codec.decode(frame) else { continue }
            apply(update)
        }
    }

    private func apply(_ update: Update) {
        switch update {
        case .firmware(let text):
            state.firmware = text
            state.model = ModelInfo.identify(firmware: text)
        case .battery(let part, let percent):
            switch part {
            case .left: state.battery.left = percent
            case .right: state.battery.right = percent
            case .chargingCase: state.battery.chargingCase = percent
            }
        case .feature(let feature, let value):
            state.values[feature] = value
        case .keys(let keys):
            state.keys.merge(keys) { _, new in new }
        }
    }

    // MARK: Settings

    func set(_ feature: Feature, _ value: Int) {
        state.values[feature] = value
        send([Request.set(feature, value)])
        readBack(Request.get(feature))
    }

    func setKey(_ gesture: TouchGesture, _ action: KeyAction) {
        state.keys[gesture] = action
        send([Request.setKey(gesture, action)])
        readBack(Request.keys)
    }

    // MARK: Equalizer (write-only, unverified on a real T3 Pro)

    func setEqGain(at index: Int, to gain: Int) {
        guard eqGains.indices.contains(index) else { return }
        eqGains[index] = gain
        eqPreset = nil
        saveEq()
        // Debounce: one curve is 14 frames at 50 ms, so only the last drag position is sent.
        eqWork?.cancel()
        let gains = eqGains
        let work = DispatchWorkItem { [weak self] in
            self?.send(T3ProEq.frames(for: T3ProEq.curve(userGains: gains)))
        }
        eqWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func applyClassicEq() {
        eqWork?.cancel()
        eqGains = Array(repeating: 0, count: T3ProEq.userBands.count)
        eqPreset = nil
        saveEq()
        send(T3ProEq.frames(for: T3ProEq.classic))
    }

    func applyPreset(_ preset: EqPreset) {
        eqWork?.cancel()
        eqGains = Array(repeating: 0, count: T3ProEq.userBands.count)
        eqPreset = preset.name
        saveEq()
        send(T3ProEq.frames(for: preset.bands))
    }

    private var eqKey: String { "eq.\(address ?? "default")" }

    private func saveEq() {
        UserDefaults.standard.set(["gains": eqGains, "preset": eqPreset ?? ""] as [String: Any], forKey: eqKey)
    }

    private func loadEq() {
        guard let saved = UserDefaults.standard.dictionary(forKey: eqKey) else { return }
        if let gains = saved["gains"] as? [Int], gains.count == T3ProEq.userBands.count { eqGains = gains }
        let preset = saved["preset"] as? String
        eqPreset = (preset?.isEmpty == false) ? preset : nil
    }
}
