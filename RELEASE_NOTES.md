## PeatsMac 0.3.0

A macOS menu bar app for SoundPEATS T3 Pro earbuds. Universal binary (Intel + Apple Silicon), macOS 13+.

**Highlights**
- Glass-style panel: frosted background, blurred glass cards, bright rim light.
- Menu bar: AirPods Pro icon with the left·right battery next to it (for example `82·79`); the icon dims until the earbuds are connected.
- Battery for left, right and case; Noise Control (ANC / Transparency / Off); Prompt Volume.
- Quick Settings: Game Mode, Light Effect, Lock Touch, Dynamic EQ, Movie Mode, Panoramic Sound, Dual Connection, voice prompt language, device info.
- Controls: tap, double tap, triple tap and tap & hold for each earbud.
- Equalizer (presets, curve, 8 bands, saved presets) and the Dual Connection device list are experimental on the T3 Pro.
- Earbuds renamed in macOS are recognised, or you can pick them from a list.

Only controls your earbuds actually answer are shown.

**Install**
1. Download `PeatsMac.zip` below and unzip it.
2. In Terminal: `xattr -cr ~/Downloads/PeatsMac.app` (ad-hoc signed, not notarized).
3. Connect the T3 Pro in System Settings → Bluetooth, close PeatsAudio on your phone, then open PeatsMac and allow Bluetooth access.

Debug log: `PEATS_DEBUG=1 ~/Downloads/PeatsMac.app/Contents/MacOS/PeatsMac`

Credits: panel layout, Bluetooth transport and app structure adapted from [nothing-x-mac](https://github.com/farhancdr/nothing-x-mac) by farhancdr; protocol research by [PairFree](https://github.com/Omega-Destroyer/PairFree).
