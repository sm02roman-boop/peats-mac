# SoundPEATS T3 Pro protocol

What PeatsMac sends, where each fact comes from, and how sure we are.

## Provenance

None of this was captured by this project on a T3 Pro. It is assembled from public work:

| Source | What it gives |
| --- | --- |
| [PairFree](https://github.com/Omega-Destroyer/PairFree) `docs/soundpeats/PROTOCOL.md` | Static analysis of PeatsAudio 1.9.45 (`com.xingkeqi.peats`, not obfuscated): transport, frame layout, command table, EQ encoding |
| PairFree `data/soundpeats/reports/ZKLXT3PRO_0.0.31.txt` | A real probe of a T3 Pro (firmware `ZKLXT3PRO_20250428_v0.0.31`): which GETs it answers, with raw bytes |
| PairFree `data/soundpeats/devices.json` | The T3 Pro's EQ curves as the official app writes them |

PairFree marks the T3 Pro's EQ as untested ("Untested." in `devices.json`). Everything else
the T3 Pro answered in the probe, but PairFree only *read* it; SETs are taken from the app's
command table and have been confirmed on other models (H3, Air5 Pro+), not on a T3 Pro.

## Transport

- Bluetooth Classic, Serial Port Profile (UUID `00001101-0000-1000-8000-00805F9B34FB`) over RFCOMM.
  The channel id comes from the device's SDP record.
- The earbuds must be connected in macOS Bluetooth first. There is no pairing, handshake or login on the control channel.
- One client at a time: close PeatsAudio on your phone before using PeatsMac.
- The T3 Pro is a Bluetrum chip ("FOTA" family in PeatsAudio). Every non-QCY SoundPEATS model uses the same frames.

## Frame

Big-endian, no checksum, same layout both ways.

| Offset | Size | Field |
| --- | --- | --- |
| 0 | 1 | `FF` start |
| 1 | 1 | version: phone sends `04`, earbuds may answer `03` |
| 2 | 1 | flags `00` |
| 3 | 1 | payload length |
| 4–5 | 2 | vendor: `00 0A` normal, `00 1D` EQ writes |
| 6–7 | 2 | command |
| 8… | n | payload |

A GET is `03 xx` with no payload. The reply has the top bit set (`83 xx`) and carries `[status, value]`
with status `00` = OK. A GET the firmware lacks gets **no reply**, so PeatsMac probes everything and
shows only what answered. A SET usually gets no reply of its own; the app reads the value back 0.6 s later.

## Commands used (all values single bytes unless noted)

| Feature | GET | SET | Values | T3 Pro probe |
| --- | --- | --- | --- | --- |
| Firmware | `03 09` | | ASCII `CODE_date_vX.Y.Z` | `ZKLXT3PRO_20250428_v0.0.31` |
| Battery L / R / case | `03 06` / `03 07` / `03 23` | | percent; 255 = unavailable | 80 / 255 / 25 |
| Noise control | `03 10` | `03 11` | 0 off, 1 ANC, 2 transparency | answered (0) |
| Game mode | `03 0E` | `03 0F` | 0/1 | answered |
| Dual connection | `03 14` | `03 15` | 0/1 | answered (1) |
| Lock touch | `03 12` | `03 13` | 0/1 | answered (0) |
| Prompt volume | `03 19` | `03 20` | 0–100 | answered (25) |
| Prompt language | `03 21` | `03 22` | 0 en, 1 zh, 2 de, 3 ja, 4 fr, 5 es, 6 it | answered (0) |
| Dynamic EQ | `03 31` | `03 32` | 0/1 | answered |
| Movie mode | `03 27` | `03 28` | 0/1 | answered |
| Panoramic sound | `03 29` | `03 30` | 0 normal, 1 music, 2 movie | answered |
| Light effect | `03 0A` | `03 0B` | 0/1 | answered (1) |
| Touch gestures | `03 AA` | `03 AB` | see below | answered |

Not answered by the T3 Pro (so not offered): ANC levels, transparency level, in-ear detection,
LDAC, LE Audio, auto shutdown, spatial audio, Dolby, adaptive volume, find earbuds, fit test, water drain.

### Dual connection devices (experimental)

`03 52` lists the phones the earbuds know: each reply is `[entry, connected, address×6, name…, 0]`
(on `S13` a 41-byte reply has one extra leading byte). `03 53` with `[address×6, 1|0]` connects or
disconnects one. Both come from SOUNDPEATS 2.5.3 via PairFree, were **not** in the T3 Pro probe (PairFree
never reads `03 52` unasked, because it holds other people's names), and how entries are enumerated is
unknown. PeatsMac only sends them when you press *Load devices* / *Connect*. If the T3 Pro stays silent,
only the on/off switch (`03 14` / `03 15`) exists on this firmware.

### Touch gestures

SET payload `[gesture, action]`, one gesture per frame. Gestures: 1 tap L, 2 tap R, 3 double L, 4 double R,
5 triple L, 6 triple R, 7 hold L, 8 hold R. Actions: 0 none, 1 volume up, 2 volume down, 3 play/pause,
4 game mode, 5 previous, 6 next, 7 ANC cycle, 8 voice assistant. The GET reply is the 16 bytes of
`(gesture, action)` pairs; the real T3 reply is
`01 02 02 01 03 05 04 03 05 03 06 08 07 07 08 06` = tap L vol-, tap R vol+, double L prev, double R play/pause,
triple L play/pause, triple R assistant, hold L ANC, hold R next. (Qualcomm models prepend a status byte; the decoder handles both.)

## Equalizer (write-only, unverified on a T3 Pro)

One frame per band, vendor `00 1D`, command `0E 02`, 10-byte payload:

```
[count] [index from 1] [master dB×60 s16] [centre Hz×3 u16] [gain dB×60 s16] [Q×4096 u16]
```

Example (from PairFree): 63 Hz, +3.5 dB, Q 0.7, master 0, 9 bands, band 1 → `09 01 00 00 00 BD 00 D2 0B 33`.

For the T3 Pro the official app sends 14 bands: six fixed "classic" bands (35, 210, 350, 630, 1300, 2300 Hz),
then eight user bands (62 Hz … 8 kHz, Q 1.8, ±6 dB). Master gain is −5 dB on every frame. Presets are
complete 14-band curves. The earbuds cannot report their EQ, so PeatsMac remembers what it last sent.

## Re-deriving or extending this

- Record your own: on Android turn on *Developer options → Enable Bluetooth HCI snoop log*, use PeatsAudio, then
  open the log in Wireshark and filter `btrfcomm`. Frames start with `FF 04 00`.
- On macOS: `PEATS_DEBUG=1 swift run PeatsMac` logs every frame in hex.
- If the channel won't open: `PEATS_CHANNEL=<n>` skips SDP; `PEATS_DEVICE=<name>` matches a renamed device.
