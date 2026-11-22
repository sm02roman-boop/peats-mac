#!/usr/bin/env python3
"""Regenerate Sources/PeatsKit/T3ProEqData.swift from PairFree's devices.json.

    python3 tools/gen_t3pro_eq.py path/to/PairFree/data/soundpeats/devices.json
"""
import json, sys, pathlib

src = pathlib.Path(sys.argv[1])
d = json.loads(src.read_text())
e = next(x for x in d["devices"] if x.get("firmware_code") == "ZKLXT3PRO")["eq"]

def band(b, gain_key="gain_db"):
    return f'EqBand(hz: {b["hz"]}, q: {b["q"]}, gainDb: {b[gain_key]})'

o = [
    "// GENERATED from PairFree data/soundpeats/devices.json (ZKLXT3PRO entry) by tools/gen_t3pro_eq.py.",
    "// Do not edit by hand. Curves are the ones the official app sends; see docs/PROTOCOL.md.",
    "",
    "extension T3ProEq {",
    f'    public static let masterGainDb: Double = {e["master_gain_db"]}',
    f'    public static let userRangeDb = {e["user_range_db"]}',
    "    /// The classic curve's six bands, always sent first and unchanged.",
    "    public static let fixedBands: [EqBand] = [",
    *[f"        {band(b)}," for b in e["fixed_bands"]],
    "    ]",
    "    /// The eight user-adjustable bands (base gain 0), appended after the fixed ones.",
    "    public static let userBands: [EqBand] = [",
    *[f"        {band(b, 'base_gain_db')}," for b in e["bands"]],
    "    ]",
    "    /// Complete 14-band curves, sent as they are.",
    "    public static let presets: [EqPreset] = [",
]
for p in e["presets"]:
    o.append(f'        EqPreset(name: "{p["name"]}", bands: [')
    o += [f"            {band(b)}," for b in p["bands"]]
    o.append("        ]),")
o += ["    ]", "}", ""]
out = pathlib.Path(__file__).resolve().parent.parent / "Sources/PeatsKit/T3ProEqData.swift"
out.write_text("\n".join(o))
print("wrote", out)
