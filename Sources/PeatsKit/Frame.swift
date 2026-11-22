// SoundPEATS control frame (Qualcomm GAIA serial framing carrying SoundPEATS' own
// command set). Same layout both ways, big-endian, no checksum.
//
//   [0]    0xFF start byte
//   [1]    version  (phone sends 0x04; some earbuds answer 0x03, so never insist on it)
//   [2]    flags    0x00
//   [3]    payload length
//   [4..5] vendor   0x000A normal commands, 0x001D EQ writes
//   [6..7] command  e.g. 0x0309 = GET firmware; a GET reply has the top bit set (0x8309)
//   [8..]  payload

public enum Frame {
    public static let startByte: UInt8 = 0xFF
    public static let version: UInt8 = 0x04
    public static let headerLength = 8
    public static let vendorMain: UInt16 = 0x000A
    public static let vendorEQ: UInt16 = 0x001D

    public static func encode(command: UInt16, payload: [UInt8] = [], vendor: UInt16 = Frame.vendorMain) -> [UInt8] {
        precondition(payload.count <= 255, "payload too long")
        var bytes: [UInt8] = [startByte, version, 0x00, UInt8(payload.count)]
        bytes.append(UInt8(vendor >> 8))
        bytes.append(UInt8(vendor & 0xFF))
        bytes.append(UInt8(command >> 8))
        bytes.append(UInt8(command & 0xFF))
        bytes += payload
        return bytes
    }
}

public struct IncomingFrame: Equatable {
    public let version: UInt8
    public let vendor: UInt16
    public let command: UInt16
    public let payload: [UInt8]

    public init(version: UInt8, vendor: UInt16, command: UInt16, payload: [UInt8]) {
        self.version = version
        self.vendor = vendor
        self.command = command
        self.payload = payload
    }
}

/// Turns the RFCOMM byte stream into frames. One read can hold several frames or
/// part of one, so this buffers and splits by the length byte.
public struct FrameParser {
    private var buffer: [UInt8] = []
    private static let maxBuffer = 4096

    public init() {}

    public mutating func push(_ chunk: [UInt8]) -> [IncomingFrame] {
        buffer += chunk
        var frames: [IncomingFrame] = []

        while true {
            guard let start = buffer.firstIndex(of: Frame.startByte) else {
                buffer.removeAll()
                break
            }
            if start > 0 { buffer.removeFirst(start) }
            guard buffer.count >= Frame.headerLength else { break }

            let total = Frame.headerLength + Int(buffer[3])
            guard buffer.count >= total else { break }

            frames.append(IncomingFrame(
                version: buffer[1],
                vendor: UInt16(buffer[4]) << 8 | UInt16(buffer[5]),
                command: UInt16(buffer[6]) << 8 | UInt16(buffer[7]),
                payload: Array(buffer[Frame.headerLength..<total])
            ))
            buffer.removeFirst(total)
        }

        if buffer.count > Self.maxBuffer { buffer.removeAll() }
        return frames
    }

    public mutating func reset() { buffer.removeAll() }
}
