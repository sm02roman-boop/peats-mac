#!/usr/bin/env python3
"""Independent Python implementation of the PeatsKit wire format.

No Swift toolchain was available where PeatsKit was written, so this re-derives every
test vector in Sources/PeatsKitChecks/main.swift from the protocol notes, and also parses
the generated EQ data straight out of T3ProEqData.swift to check each curve fits the wire
format (frequency x3 and Q x4096 in 16 bits, gain in range).

    python3 tools/mirror_check.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
failures = 0


def check(cond, msg):
    global failures
    if not cond:
        failures += 1
        print("FAIL:", msg)


def encode(command, payload=(), vendor=0x000A, version=0x04):
    return bytes([0xFF, version, 0, len(payload), vendor >> 8, vendor & 0xFF, command >> 8, command & 0xFF, *payload])


def hx(b):
    return " ".join(f"{x:02X}" for x in b)


def round_away(x):
    return int(x + 0.5) if x >= 0 else -int(-x + 0.5)


def units(db):
    return round_away(round_away(db * 100) * 0.6)


def eq_payload(count, index, hz, q, gain, master):
    def s16(v):
        return (v & 0xFFFF).to_bytes(2, "big")

    return bytes([count, index]) + s16(units(master)) + (hz * 3).to_bytes(2, "big") + s16(units(gain)) + int(q * 4096).to_bytes(2, "big")


def parse(stream):
    out, buf = [], bytearray(stream)
    while True:
        if 0xFF not in buf:
            break
        del buf[: buf.index(0xFF)]
        if len(buf) < 8 or len(buf) < 8 + buf[3]:
            break
        total = 8 + buf[3]
        out.append((buf[1], (buf[4] << 8) | buf[5], (buf[6] << 8) | buf[7], bytes(buf[8:total])))
        del buf[:total]
    return out


# Encoding vectors (PairFree docs/soundpeats/PROTOCOL.md section 2, plus SET examples)
check(hx(encode(0x0309)) == "FF 04 00 00 00 0A 03 09", "GET firmware")
check(hx(encode(0x0311, [2])) == "FF 04 00 01 00 0A 03 11 02", "SET noise transparency")
check(hx(encode(0x030F, [1])) == "FF 04 00 01 00 0A 03 0F 01", "SET game mode")
check(hx(encode(0x03AB, [7, 7])) == "FF 04 00 02 00 0A 03 AB 07 07", "SET hold L = ANC")

# EQ vector: 63 Hz, +3.5 dB, Q 0.7, 9 bands, index 1, master 0
check(hx(eq_payload(9, 1, 63, 0.7, 3.5, 0)) == "09 01 00 00 00 BD 00 D2 0B 33", "EQ band payload")
check(units(4.1) == 246, "4.1 dB -> 246")
check(units(-5) == -300, "master -5 dB -> -300")

# Parser: split + merged frames, resync, version 03
bat = encode(0x8306, [0, 0x50], version=3)
two = parse(bat[:5] + bat[5:] + encode(0x8323, [0, 0x19], version=3))
check(len(two) == 2 and two[0][2] == 0x8306 and two[0][3] == bytes([0, 0x50]), "parser split+merge")
check(len(parse(b"\x00\x12\x34" + encode(0x8310, [0, 1], version=3))) == 1, "parser resync")

# Real T3 Pro report: custom keys, 16 bytes with no status byte
raw = bytes.fromhex("01 02 02 01 03 05 04 03 05 03 06 08 07 07 08 06")
pairs = {raw[i]: raw[i + 1] for i in range(0, 16, 2)}
check(pairs == {1: 2, 2: 1, 3: 5, 4: 3, 5: 3, 6: 8, 7: 7, 8: 6}, "custom keys decode")

# Generated EQ data
src = (ROOT / "Sources/PeatsKit/T3ProEqData.swift").read_text()
master = float(re.search(r"masterGainDb: Double = (-?[\d.]+)", src).group(1))
bands = re.findall(r"EqBand\(hz: (\d+), q: ([\d.]+), gainDb: (-?[\d.]+)\)", src)
check(len(bands) == 6 + 8 + 11 * 14, f"expected 6+8+154 EqBand literals, found {len(bands)}")
for hz, q, g in bands:
    hz, q, g = int(hz), float(q), float(g)
    check(0 < hz * 3 <= 0xFFFF, f"frequency {hz} Hz fits u16 x3")
    check(0 < int(q * 4096) <= 0xFFFF, f"Q {q} fits u16 x4096")
    check(abs(units(g)) <= 0x7FFF, f"gain {g} fits s16 x60")
check(abs(units(master)) <= 0x7FFF, "master gain fits")
print("master gain", master, "dB ->", units(master), "units ->", f"{units(master) & 0xFFFF:04X}")

if failures:
    print(failures, "failure(s)")
    sys.exit(1)
print("All mirror checks passed.")
