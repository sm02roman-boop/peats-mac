// `swift run PeatsKitChecks`: protocol self-checks (XCTest is not available without Xcode).
// Every vector below is either taken from PairFree's protocol notes or from the real T3 Pro
// device report (ZKLXT3PRO_20250428_v0.0.31). tools/mirror_check.py checks the same vectors in Python.

import Foundation
import PeatsKit

var failures = 0

func check(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition {
        failures += 1
        print("FAIL (line \(line)): \(message)")
    }
}

func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02X", $0) }.joined(separator: " ") }

func frame(_ command: UInt16, _ payload: [UInt8], version: UInt8 = 0x03) -> [UInt8] {
    var f = Frame.encode(command: command, payload: payload)
    f[1] = version
    return f
}

// MARK: Encoding

check(hex(Frame.encode(command: 0x0309)) == "FF 04 00 00 00 0A 03 09", "GET firmware")
check(hex(Frame.encode(command: 0x0311, payload: [2])) == "FF 04 00 01 00 0A 03 11 02", "SET noise = transparency")
check(hex(Request.set(.gameMode, 1)) == "FF 04 00 01 00 0A 03 0F 01", "SET game mode")
check(hex(Request.setKey(.holdLeft, .noiseControl)) == "FF 04 00 02 00 0A 03 AB 07 07", "SET key hold L = ANC cycle")
check(hex(Request.get(.lightEffect)) == "FF 04 00 00 00 0A 03 0A", "GET light effect")
check(Request.probe.count == 1 + 3 + Feature.allCases.count + 1, "probe covers every read")

// MARK: EQ (doc example: band 1 of 9, 63 Hz, +3.5 dB, Q 0.7, master 0 -> 0E 02 variant)

let sample = T3ProEq.payload(count: 9, index: 1, band: EqBand(hz: 63, q: 0.7, gainDb: 3.5), masterGainDb: 0)
check(hex(sample) == "09 01 00 00 00 BD 00 D2 0B 33", "EQ band payload: \(hex(sample))")
check(T3ProEq.signedUnits(4.1) == 246, "4.1 dB rounds to 246 units")
check(T3ProEq.signedUnits(-5) == -300, "master -5 dB is -300 units")

let classic = T3ProEq.frames(for: T3ProEq.classic)
check(classic.count == 14, "classic curve has 14 bands")
check(classic.allSatisfy { $0[5] == 0x1D && $0[6] == 0x0E && $0[7] == 0x02 }, "EQ frames use vendor 00 1D and command 0E 02")
check(classic.allSatisfy { $0[8] == 14 }, "every EQ frame carries the band count")
check(classic.enumerated().allSatisfy { Int($0.element[9]) == $0.offset + 1 }, "EQ band indexes run 1...14")
check(T3ProEq.presets.count == 11 && T3ProEq.presets.allSatisfy { $0.bands.count == 14 }, "11 presets of 14 bands")

// MARK: Parser

var parser = FrameParser()
let battery = frame(0x8306, [0x00, 0x50])
let split = Array(battery[0..<5])
check(parser.push(split).isEmpty, "partial frame waits")
let rest = parser.push(Array(battery[5...]) + frame(0x8323, [0x00, 0x19]))
check(rest.count == 2, "split frame completes and a second one follows in the same read")
check(rest.first?.command == 0x8306 && rest.first?.payload == [0x00, 0x50], "battery frame fields")
check(rest.first?.version == 0x03, "version 03 from the earbuds is accepted")

var noisy = FrameParser()
let framed = noisy.push([0x00, 0x12, 0x34] + frame(0x8310, [0, 1]))
check(framed.count == 1 && framed[0].command == 0x8310, "parser resyncs on 0xFF")

// MARK: Decoding, with the bytes from the real T3 Pro report

func decode(_ command: UInt16, _ payload: [UInt8]) -> Update? {
    Codec.decode(IncomingFrame(version: 3, vendor: 0x000A, command: command, payload: payload))
}

let firmware = Array("ZKLXT3PRO_20250428_v0.0.31".utf8)
check(decode(0x8309, firmware) == .firmware("ZKLXT3PRO_20250428_v0.0.31"), "firmware reply")
check(decode(0x8309, [0x00] + firmware) == .firmware("ZKLXT3PRO_20250428_v0.0.31"), "firmware reply with status byte")
check(decode(0x8306, [0x00, 0x50]) == .battery(.left, percent: 80), "battery left 80")
check(decode(0x8307, [0x00, 0xFF]) == .battery(.right, percent: nil), "battery right 255 = unavailable")
check(decode(0x8323, [0x00, 0x19]) == .battery(.chargingCase, percent: 25), "battery case 25")
check(decode(0x8306, [0x01, 0x50]) == nil, "battery with status 1 is ignored")
check(decode(0x8310, [0x00, 0x00]) == .feature(.noise, value: 0), "noise off")
check(decode(0x830E, [0x00, 0x00]) == .feature(.gameMode, value: 0), "game mode")
check(decode(0x8314, [0x00, 0x01]) == .feature(.multipoint, value: 1), "multipoint on")
check(decode(0x8319, [0x00, 0x19]) == .feature(.promptVolume, value: 25), "prompt volume 25")
check(decode(0x830A, [0x00, 0x01]) == .feature(.lightEffect, value: 1), "light effect on")
check(decode(0x830F, [0x00, 0x00]) == nil, "a SET number is not a GET reply")

let keyBytes: [UInt8] = [0x01, 0x02, 0x02, 0x01, 0x03, 0x05, 0x04, 0x03, 0x05, 0x03, 0x06, 0x08, 0x07, 0x07, 0x08, 0x06]
if case .keys(let keys)? = decode(0x83AA, keyBytes) {
    check(keys.count == 8, "eight gestures")
    check(keys[.tapLeft] == .volumeDown && keys[.tapRight] == .volumeUp, "tap L vol-, R vol+")
    check(keys[.doubleLeft] == .previous && keys[.doubleRight] == .playPause, "double L prev, R play/pause")
    check(keys[.tripleLeft] == .playPause && keys[.tripleRight] == .assistant, "triple L play/pause, R assistant")
    check(keys[.holdLeft] == .noiseControl && keys[.holdRight] == .next, "hold L ANC, R next")
} else {
    check(false, "custom keys reply did not decode")
}
if case .keys(let keys)? = decode(0x83AA, [0x00] + keyBytes) {
    check(keys.count == 8, "custom keys with a leading status byte (Qualcomm layout)")
} else {
    check(false, "custom keys with status byte did not decode")
}

// MARK: Dual connection devices (03 52 / 03 53)

if case .knownPhone(let phone)? = decode(0x8352, [1, 1, 0xAA, 0xBB, 0xCC, 0x01, 0x02, 0x03] + Array("MacBook".utf8) + [0]) {
    check(phone.index == 1 && phone.isConnected, "known phone entry and connected flag")
    check(phone.addressText == "AA:BB:CC:01:02:03" && phone.name == "MacBook", "known phone address and name")
} else {
    check(false, "known phone reply did not decode")
}
check(hex(Request.connectPhone(address: [1, 2, 3, 4, 5, 6], connect: false)) == "FF 04 00 07 00 0A 03 53 01 02 03 04 05 06 00", "connect phone frame")
check(!Request.probe.contains(Request.knownPhones), "probe never asks for other people's device names")

// MARK: Model

check(ModelInfo.parse(firmware: "ZKLXT3PRO_20250428_v0.0.31").code == "ZKLXT3PRO", "firmware code")
check(ModelInfo.parse(firmware: "ZKLXT3PRO_20250428_v0.0.31").version == "0.0.31", "firmware version")
check(ModelInfo.identify(firmware: "ZKLXT3PRO_20250428_v0.0.31").verified, "T3 Pro is a verified model")
check(!ModelInfo.identify(firmware: "SOMETHINGELSE_1_v1").verified, "unknown model is unverified")

if failures == 0 {
    print("All PeatsKit checks passed.")
} else {
    print("\(failures) check(s) failed.")
    exit(1)
}
