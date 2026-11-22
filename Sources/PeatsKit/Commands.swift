// Command numbers and payload codecs for the SoundPEATS common protocol.
// Numbers come from PeatsAudio's `FunctionEnum` as documented by PairFree
// (github.com/Omega-Destroyer/PairFree, docs/soundpeats/PROTOCOL.md) and from a real
// T3 Pro report (firmware ZKLXT3PRO_20250428_v0.0.31). See docs/PROTOCOL.md.

// MARK: - Simple on/off or enum features

/// A setting with one GET and one SET command whose value is a single byte.
public enum Feature: CaseIterable, Hashable {
    case noise, gameMode, multipoint, touchLock, promptVolume, voiceLanguage
    case dynamicEq, movieMode, panoramic, lightEffect

    public var getCommand: UInt16 {
        switch self {
        case .noise: return 0x0310
        case .gameMode: return 0x030E
        case .multipoint: return 0x0314
        case .touchLock: return 0x0312
        case .promptVolume: return 0x0319
        case .voiceLanguage: return 0x0321
        case .dynamicEq: return 0x0331
        case .movieMode: return 0x0327
        case .panoramic: return 0x0329
        case .lightEffect: return 0x030A
        }
    }

    public var setCommand: UInt16 {
        switch self {
        case .noise: return 0x0311
        case .gameMode: return 0x030F
        case .multipoint: return 0x0315
        case .touchLock: return 0x0313
        case .promptVolume: return 0x0320
        case .voiceLanguage: return 0x0322
        case .dynamicEq: return 0x0332
        case .movieMode: return 0x0328
        case .panoramic: return 0x0330
        case .lightEffect: return 0x030B
        }
    }

    /// The command the earbuds answer a GET with: the same number, top bit set.
    public var replyCommand: UInt16 { getCommand | 0x8000 }
}

public enum NoiseMode: Int, CaseIterable, Identifiable {
    case off = 0, anc = 1, transparency = 2
    public var id: Int { rawValue }
    public var label: String {
        switch self {
        case .off: return "Off"
        case .anc: return "ANC"
        case .transparency: return "Transparency"
        }
    }
}

public enum VoiceLanguage: Int, CaseIterable, Identifiable {
    case english = 0, chinese, german, japanese, french, spanish, italian
    public var id: Int { rawValue }
    public var label: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        case .german: return "Deutsch"
        case .japanese: return "日本語"
        case .french: return "Français"
        case .spanish: return "Español"
        case .italian: return "Italiano"
        }
    }
}

public enum PanoramicMode: Int, CaseIterable, Identifiable {
    case normal = 0, music, movie
    public var id: Int { rawValue }
    public var label: String {
        switch self {
        case .normal: return "Normal"
        case .music: return "Music"
        case .movie: return "Movie"
        }
    }
}

// MARK: - Touch gestures

public enum TouchGesture: UInt8, CaseIterable, Identifiable {
    case tapLeft = 1, tapRight, doubleLeft, doubleRight, tripleLeft, tripleRight, holdLeft, holdRight
    public var id: UInt8 { rawValue }

    public var isLeft: Bool { rawValue % 2 == 1 }

    public var kind: String {
        switch self {
        case .tapLeft, .tapRight: return "Tap"
        case .doubleLeft, .doubleRight: return "Double tap"
        case .tripleLeft, .tripleRight: return "Triple tap"
        case .holdLeft, .holdRight: return "Press and hold"
        }
    }
}

public enum KeyAction: UInt8, CaseIterable, Identifiable {
    case none = 0, volumeUp, volumeDown, playPause, gameMode, previous, next, noiseControl, assistant
    public var id: UInt8 { rawValue }
    public var label: String {
        switch self {
        case .none: return "None"
        case .volumeUp: return "Volume Up"
        case .volumeDown: return "Volume Down"
        case .playPause: return "Play / Pause"
        case .gameMode: return "Game Mode"
        case .previous: return "Previous Track"
        case .next: return "Next Track"
        case .noiseControl: return "Noise Control"
        case .assistant: return "Voice Assistant"
        }
    }
}

// MARK: - Battery

public enum BatteryPart: CaseIterable {
    case left, right, chargingCase

    public var getCommand: UInt16 {
        switch self {
        case .left: return 0x0306
        case .right: return 0x0307
        case .chargingCase: return 0x0323
        }
    }
}

// MARK: - Requests

public enum Request {
    public static let firmware = Frame.encode(command: 0x0309)
    public static let keys = Frame.encode(command: 0x03AA)

    public static func get(_ feature: Feature) -> [UInt8] {
        Frame.encode(command: feature.getCommand)
    }

    public static func set(_ feature: Feature, _ value: Int) -> [UInt8] {
        Frame.encode(command: feature.setCommand, payload: [UInt8(clamping: value)])
    }

    public static func get(_ part: BatteryPart) -> [UInt8] {
        Frame.encode(command: part.getCommand)
    }

    public static var battery: [[UInt8]] { BatteryPart.allCases.map { get($0) } }

    /// One gesture per frame: `[gesture, action]`.
    public static func setKey(_ gesture: TouchGesture, _ action: KeyAction) -> [UInt8] {
        Frame.encode(command: 0x03AB, payload: [gesture.rawValue, action.rawValue])
    }

    /// Everything read-only the app knows, in the order PeatsAudio asks. A GET the firmware
    /// does not support gets no reply at all, so the answers decide which controls exist.
    public static var probe: [[UInt8]] {
        var frames: [[UInt8]] = [firmware]
        frames += battery
        frames += Feature.allCases.map { feature in get(feature) }
        frames.append(keys)
        return frames
    }
}

// MARK: - Replies

public enum Update: Equatable {
    case firmware(String)
    case battery(BatteryPart, percent: Int?)
    case feature(Feature, value: Int)
    case keys([TouchGesture: KeyAction])
}

public enum Codec {
    /// Decodes one incoming frame. Returns nil for anything that is not a known GET reply
    /// (SET acknowledgements, EQ acks, commands this app does not use).
    public static func decode(_ frame: IncomingFrame) -> Update? {
        let payload = frame.payload

        switch frame.command {
        case 0x8309:
            return firmware(payload).map { .firmware($0) }
        case 0x83AA:
            return .keys(keys(payload))
        default:
            break
        }

        for part in BatteryPart.allCases where frame.command == part.getCommand | 0x8000 {
            // Status 1 and 2 are "not available"; the app ignores those replies.
            guard let value = statusValue(payload) else { return nil }
            // 255 (and anything over 100) means "not in the case / not connected".
            return .battery(part, percent: value <= 100 ? value : nil)
        }

        for feature in Feature.allCases where frame.command == feature.replyCommand {
            guard let value = statusValue(payload) else { return nil }
            return .feature(feature, value: value)
        }
        return nil
    }

    /// `[status, value]` with status 0 = success.
    static func statusValue(_ payload: [UInt8]) -> Int? {
        guard payload.count >= 2, payload[0] == 0 else { return nil }
        return Int(payload[1])
    }

    /// ASCII like `ZKLXT3PRO_20250428_v0.0.31`. Some firmwares prefix a status byte.
    static func firmware(_ payload: [UInt8]) -> String? {
        let bytes = payload.first == 0 ? Array(payload.dropFirst()) : payload
        let text = String(decoding: bytes.filter { $0 >= 0x20 && $0 < 0x7F }, as: UTF8.self)
        return text.isEmpty ? nil : text
    }

    /// `(gesture, action)` pairs. Qualcomm models put a status byte first, which makes the
    /// length odd; the T3 Pro sends the 16 bytes bare.
    static func keys(_ payload: [UInt8]) -> [TouchGesture: KeyAction] {
        let bytes = payload.count % 2 == 1 ? Array(payload.dropFirst()) : payload
        var result: [TouchGesture: KeyAction] = [:]
        var index = 0
        while index + 1 < bytes.count {
            if let gesture = TouchGesture(rawValue: bytes[index]), let action = KeyAction(rawValue: bytes[index + 1]) {
                result[gesture] = action
            }
            index += 2
        }
        return result
    }
}

// MARK: - Model

public struct ModelInfo: Equatable {
    public let displayName: String
    /// True once someone has probed this model on real earbuds.
    public let verified: Bool

    /// `ZKLXT3PRO_20250428_v0.0.31` → code `ZKLXT3PRO`, version `0.0.31`.
    public static func parse(firmware: String) -> (code: String, version: String?) {
        let parts = firmware.split(separator: "_").map(String.init)
        let code = parts.first ?? firmware
        let version = parts.last.flatMap { $0.hasPrefix("v") ? String($0.dropFirst()) : nil }
        return (code, version)
    }

    /// `S28` is the other firmware code the official app lists for the T3 Pro; it has not been probed.
    public static func identify(firmware: String?) -> ModelInfo {
        guard let firmware else { return ModelInfo(displayName: "SOUNDPEATS", verified: false) }
        switch parse(firmware: firmware).code.uppercased() {
        case "ZKLXT3PRO": return ModelInfo(displayName: "SOUNDPEATS T3 Pro", verified: true)
        case "S28": return ModelInfo(displayName: "SOUNDPEATS T3 Pro", verified: false)
        default: return ModelInfo(displayName: "SOUNDPEATS", verified: false)
        }
    }
}
