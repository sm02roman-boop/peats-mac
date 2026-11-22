# PeatsMac

A menu bar app for macOS that controls **SoundPEATS T3 Pro** earbuds (the job PeatsAudio does on a phone):
battery, ANC / transparency, game mode, dual connection, touch controls, voice prompts and an 8-band equalizer.

It is a re-implementation of [nothing-x-mac](https://github.com/farhancdr/nothing-x-mac) for the SoundPEATS protocol:
same app structure (RFCOMM over IOBluetooth, a protocol library with no UI, a menu bar popover), different wire format and its own UI.
See [docs/PROTOCOL.md](docs/PROTOCOL.md) for the protocol and where each fact comes from.

## Credits

App structure (Bluetooth transport, menu bar item) adapted from [nothing-x-mac](https://github.com/farhancdr/nothing-x-mac) by [farhancdr](https://github.com/farhancdr) (MIT, see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)). The SoundPEATS protocol work is [PairFree](https://github.com/Omega-Destroyer/PairFree)'s.

## Status: written but not yet run on a Mac

It was written without a Swift compiler or a T3 Pro in reach. What *has* been checked:

- Every Swift file parses (tree-sitter).
- `tools/mirror_check.py` re-implements the framing/EQ maths in Python and passes against the protocol vectors
  and the real T3 Pro probe bytes.

What has **not**: compiling, running, or talking to real earbuds. Expect a few compile fixes on the first build,
and treat the equalizer as experimental.

## Build and run

```bash
swift run PeatsKitChecks      # protocol self-checks, should print "All PeatsKit checks passed."
```

```bash
PEATS_DEBUG=1 swift run PeatsMac
```

```bash
scripts/build-app.sh          # builds build/PeatsMac.app
```

1. Connect the T3 Pro in **System Settings → Bluetooth** (it must be connected for audio).
2. Close PeatsAudio on your phone; only one app can hold the control channel.
3. Launch PeatsMac and allow Bluetooth access when macOS asks.

## Layout

```
Sources/PeatsKit/        frames, command codecs, T3 Pro EQ (pure Swift, no UI/Bluetooth)
Sources/PeatsKitChecks/  self-checks (swift run PeatsKitChecks)
Sources/PeatsMac/        IOBluetooth transport, DeviceController, SwiftUI panel
tools/mirror_check.py    Python cross-check of the wire format
tools/gen_t3pro_eq.py    regenerates T3ProEqData.swift from PairFree's devices.json
```

## Other SoundPEATS models

The frames are shared by almost every SoundPEATS model, and PeatsMac only shows controls the earbuds answered,
so other models may partly work. Only the EQ is T3 Pro specific.
