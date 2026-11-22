// Bluetooth transport: finds a connected, paired SoundPEATS earbud, opens an RFCOMM channel
// on its Serial Port Profile service and relays raw bytes. It knows nothing about the
// protocol; that lives in PeatsKit. Structure follows nothing-x-mac's transport.
//
// All IOBluetooth callbacks arrive on the main run loop, so this class (and everything
// it calls) runs on the main thread.
//
// Debug switches (environment variables):
//   PEATS_DEBUG=1       log every frame in hex
//   PEATS_DEVICE=name   match paired devices whose name contains this instead of "soundpeats"
//   PEATS_CHANNEL=n     skip SDP and open this RFCOMM channel id directly

import Foundation
import IOBluetooth

final class BluetoothTransport: NSObject, IOBluetoothRFCOMMChannelDelegate {
    var onConnected: ((_ name: String, _ address: String) -> Void)?
    var onData: (([UInt8]) -> Void)?
    var onDisconnected: (() -> Void)?
    /// Name of the earbuds the channel is being opened to, or nil when there are none.
    var onConnecting: ((String?) -> Void)?

    /// Standard Serial Port Profile, 00001101-0000-1000-8000-00805F9B34FB. PeatsAudio uses
    /// exactly this UUID on Android; there is no handshake or login after the socket opens.
    private static let sppUUIDBytes: [UInt8] = [
        0x00, 0x00, 0x11, 0x01, 0x00, 0x00, 0x10, 0x00,
        0x80, 0x00, 0x00, 0x80, 0x5F, 0x9B, 0x34, 0xFB,
    ]
    private static let scanInterval: TimeInterval = 3
    private static let openTimeout: TimeInterval = 10

    private let serviceUUID: IOBluetoothSDPUUID = {
        var bytes = BluetoothTransport.sppUUIDBytes
        return IOBluetoothSDPUUID(bytes: &bytes, length: bytes.count)
    }()

    private var channel: IOBluetoothRFCOMMChannel?
    private var opening: (channel: IOBluetoothRFCOMMChannel?, device: IOBluetoothDevice, startedAt: Date)?
    private var scanTimer: Timer?
    private var sdpRequested = Set<String>()
    private var openFailures: [String: Int] = [:]
    private var linkResetDone = Set<String>()
    private var stopped = true

    var isConnected: Bool { channel != nil }

    struct PairedDevice: Identifiable, Equatable {
        let name: String
        let address: String
        var id: String { address }
    }

    private static let savedKey = "device.address"
    private static var savedAddress: String? { UserDefaults.standard.string(forKey: savedKey) }

    /// The device the user picked in the panel, or one whose (possibly renamed) name looks like SoundPEATS.
    static func matches(_ device: IOBluetoothDevice) -> Bool {
        if let saved = savedAddress, device.addressString == saved { return true }
        return isPeats(device.name)
    }

    static func isPeats(_ name: String?) -> Bool {
        guard let name = name?.lowercased() else { return false }
        if let custom = ProcessInfo.processInfo.environment["PEATS_DEVICE"]?.lowercased(), !custom.isEmpty {
            return name.contains(custom)
        }
        // macOS shows whatever the user renamed the earbuds to ("Sam's T3 Pro"), so also accept the model name.
        return name.contains("soundpeats") || name.contains("t3 pro") || name.contains("t3pro")
    }

    /// Every paired device that is connected right now, for the "choose your earbuds" list.
    static func connectedDevices() -> [PairedDevice] {
        let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        return paired.compactMap { device in
            guard device.isConnected(), let address = device.addressString else { return nil }
            return PairedDevice(name: device.nameOrAddress ?? address, address: address)
        }
    }

    /// Remember a device the user picked, and look for it straight away.
    func choose(address: String) {
        UserDefaults.standard.set(address, forKey: Self.savedKey)
        scan()
    }

    func start() {
        guard stopped else { return }
        stopped = false
        scan()
        scanTimer = Timer.scheduledTimer(withTimeInterval: Self.scanInterval, repeats: true) { [weak self] _ in
            self?.scan()
        }
    }

    /// Close the channel properly so the earbuds accept a new one next launch.
    func stop() {
        stopped = true
        scanTimer?.invalidate()
        scanTimer = nil
        if let channel {
            self.channel = nil
            channel.setDelegate(nil)
            channel.close()
        }
        if let pending = opening?.channel {
            pending.setDelegate(nil)
            pending.close()
        }
        opening = nil
    }

    func write(_ bytes: [UInt8]) {
        guard let channel, !bytes.isEmpty else { return }
        var data = bytes
        let status = data.withUnsafeMutableBytes { buffer in
            channel.writeSync(buffer.baseAddress, length: UInt16(buffer.count))
        }
        if status != kIOReturnSuccess { Log.info("Write failed (\(describe(status)))") }
    }

    // MARK: Scanning

    private func scan() {
        guard channel == nil, !stopped else { return }
        if let opening {
            // An async open that never completed: give up on it and try again.
            guard Date().timeIntervalSince(opening.startedAt) > Self.openTimeout else { return }
            opening.channel?.setDelegate(nil)
            opening.channel?.close()
            self.opening = nil
            handleOpenFailure(opening.device, status: kIOReturnTimeout)
        }
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }
        let candidates = paired.filter { $0.isConnected() && Self.matches($0) }
        if candidates.isEmpty { onConnecting?(nil) }

        for candidate in candidates {
            let address = candidate.addressString ?? ""

            var channelID: BluetoothRFCOMMChannelID = 0
            if let forced = ProcessInfo.processInfo.environment["PEATS_CHANNEL"].flatMap({ UInt8($0) }) {
                channelID = forced
            } else {
                guard let record = candidate.getServiceRecord(for: serviceUUID) else {
                    // Service list not cached yet: ask once, pick it up on a later scan.
                    if !sdpRequested.contains(address) {
                        sdpRequested.insert(address)
                        candidate.performSDPQuery(nil)
                    }
                    continue
                }
                guard record.getRFCOMMChannelID(&channelID) == kIOReturnSuccess else { continue }
            }
            Log.info("Opening RFCOMM channel \(channelID) to \(candidate.nameOrAddress ?? address)")

            var newChannel: IOBluetoothRFCOMMChannel?
            let status = candidate.openRFCOMMChannelAsync(&newChannel, withChannelID: channelID, delegate: self)
            guard status == kIOReturnSuccess else {
                handleOpenFailure(candidate, status: status)
                continue
            }
            opening = (newChannel, candidate, Date())
            onConnecting?(candidate.name ?? candidate.nameOrAddress)
            return
        }
    }

    // Opening usually fails because the earbuds still hold a channel from an earlier
    // session (or the phone app has one). Recover in two steps:
    //   1st failure: refresh the service record in case the channel id moved.
    //   3rd failure: drop and re-establish the Bluetooth link once (brief audio blip).
    private func handleOpenFailure(_ device: IOBluetoothDevice, status: IOReturn) {
        let address = device.addressString ?? ""
        let attempt = (openFailures[address] ?? 0) + 1
        openFailures[address] = attempt
        let name = device.nameOrAddress ?? "device"
        Log.info("Could not open channel to \(name) (\(describe(status))), attempt \(attempt)")

        if attempt == 1 {
            device.performSDPQuery(nil)
        }
        if attempt == 3 && !linkResetDone.contains(address) {
            linkResetDone.insert(address)
            Log.info("Resetting Bluetooth link to \(name) to clear a stale channel")
            device.closeConnection()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                _ = device.openConnection()
            }
        }
    }

    // MARK: IOBluetoothRFCOMMChannelDelegate

    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        guard let opening, let rfcommChannel else { return }
        self.opening = nil
        let device = opening.device

        guard error == kIOReturnSuccess, !stopped else {
            if stopped { rfcommChannel.close() }
            handleOpenFailure(device, status: error)
            return
        }
        openFailures[device.addressString ?? ""] = 0
        channel = rfcommChannel
        let name = device.name ?? device.nameOrAddress ?? "SOUNDPEATS"
        Log.info("Connected to \(name)")
        onConnected?(name, device.addressString ?? "")
    }

    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!,
                           data dataPointer: UnsafeMutableRawPointer!,
                           length dataLength: Int) {
        guard rfcommChannel === channel, let dataPointer, dataLength > 0 else { return }
        let buffer = UnsafeRawBufferPointer(start: dataPointer, count: dataLength)
        onData?(Array(buffer))
    }

    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        guard rfcommChannel === channel else { return }
        channel = nil
        Log.info("Channel closed")
        onDisconnected?()
    }
}

private func describe(_ status: IOReturn) -> String {
    let code = String(format: "0x%08X", UInt32(bitPattern: status))
    switch status {
    case kIOReturnError: return "\(code) general error"
    case kIOReturnBusy: return "\(code) busy"
    case kIOReturnTimeout: return "\(code) timeout"
    case kIOReturnNotOpen: return "\(code) not open"
    case kIOReturnNoDevice: return "\(code) no device"
    default: return code
    }
}

enum Log {
    /// PEATS_DEBUG=1 logs every frame to and from the earbuds.
    static let debug = ProcessInfo.processInfo.environment["PEATS_DEBUG"] != nil

    static func info(_ message: String) { NSLog("[PeatsMac] %@", message) }

    static func frame(_ direction: String, _ bytes: [UInt8]) {
        guard debug else { return }
        info("\(direction) \(bytes.map { String(format: "%02x", $0) }.joined(separator: " "))")
    }
}
