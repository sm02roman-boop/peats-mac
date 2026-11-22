// Equalizer writes for the T3 Pro (Bluetrum family, command 0E 02, vendor 00 1D).
//
// One frame per band. Every frame carries the whole curve's band count and the master
// gain. Payload, big-endian, 10 bytes:
//
//   [count] [index from 1] [master dB×60 s16] [centre Hz×3 u16] [gain dB×60 s16] [Q×4096 u16]
//
// The firmware cannot be read back: the EQ is write-only. On the T3 Pro the official app
// sends the classic curve's six fixed bands first, then the user's eight (62 Hz … 8 kHz,
// Q 1.8, ±6 dB); presets are complete 14-band curves. UNVERIFIED on real T3 Pro hardware.

public struct EqBand: Equatable {
    public var hz: Int
    public var q: Double
    public var gainDb: Double
    public init(hz: Int, q: Double, gainDb: Double) {
        self.hz = hz
        self.q = q
        self.gainDb = gainDb
    }
}

public struct EqPreset: Equatable, Identifiable {
    public let name: String
    public let bands: [EqBand]
    public var id: String { name }
}

public enum T3ProEq {
    public static let command: UInt16 = 0x0E02

    public static var userHz: [Int] { userBands.map(\.hz) }
    public static var userRange: ClosedRange<Int> { -userRangeDb...userRangeDb }

    /// The curve the user's eight gains (whole dB) make: fixed bands, then the user bands.
    public static func curve(userGains: [Int]) -> [EqBand] {
        precondition(userGains.count == userBands.count, "need \(userBands.count) gains")
        var bands = fixedBands
        for (index, band) in userBands.enumerated() {
            var b = band
            b.gainDb += Double(userGains[index])
            bands.append(b)
        }
        return bands
    }

    /// The stock sound: the user gains all zero.
    public static var classic: [EqBand] { curve(userGains: Array(repeating: 0, count: userBands.count)) }

    /// One EQ frame per band of `bands`, with `masterGainDb` on each.
    public static func frames(for bands: [EqBand]) -> [[UInt8]] {
        bands.enumerated().map { index, band in
            Frame.encode(
                command: command,
                payload: payload(count: bands.count, index: index + 1, band: band, masterGainDb: masterGainDb),
                vendor: Frame.vendorEQ
            )
        }
    }

    public static func payload(count: Int, index: Int, band: EqBand, masterGainDb: Double) -> [UInt8] {
        let master = signedUnits(masterGainDb)
        let gain = signedUnits(band.gainDb)
        let freq = UInt16(clamping: band.hz * 3)
        let q = UInt16(clamping: Int(band.q * 4096))
        var bytes: [UInt8] = [UInt8(count), UInt8(index)]
        bytes += be(UInt16(bitPattern: master))
        bytes += be(freq)
        bytes += be(UInt16(bitPattern: gain))
        bytes += be(q)
        return bytes
    }

    /// dB × 60, rounded half away from zero in hundredths first, as the official app does,
    /// so 4.1 dB is 246 and not 4.1 × 60 = 245.99999.
    public static func signedUnits(_ db: Double) -> Int16 {
        let hundredths = (db * 100).rounded()
        let units = (hundredths * 0.6).rounded()
        return Int16(clamping: Int(units))
    }

    private static func be(_ value: UInt16) -> [UInt8] { [UInt8(value >> 8), UInt8(value & 0xFF)] }
}
