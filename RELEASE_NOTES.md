## PeatsMac 0.2.0 — new look

The panel now follows the [nothing-x-mac](https://github.com/farhancdr/nothing-x-mac) design, with SoundPEATS T3 Pro controls:

- Dot-matrix battery for left, right and case, and a Dot Bud icon with `82·79` in the menu bar.
- **Noise Control** (ANC / Transparency / Off) and **Prompt Volume** on the main page.
- **Quick Settings** tiles: Game Mode, Light Effect, Lock Touch, Dynamic EQ, Movie Mode, Panoramic Sound, Dual Connection, plus voice prompt language and device info.
- **Dual Connection** page with the device list (experimental on the T3 Pro).
- **Equalizer** page: presets, frequency curve, 8 band sliders and saved presets (experimental on the T3 Pro).
- **Controls** page: tap, double tap, triple tap and tap & hold for each earbud.

Only controls your earbuds actually answer are shown. Earbuds renamed in macOS are recognised, or you can pick them from a list.

**Install**
1. Download `PeatsMac.zip` below and unzip it.
2. In Terminal: `xattr -cr ~/Downloads/PeatsMac.app` (ad-hoc signed, not notarized).
3. Connect the T3 Pro in System Settings → Bluetooth, close PeatsAudio on your phone, then open PeatsMac and allow Bluetooth access.

**Status: early, not yet verified on real T3 Pro hardware.** Debug log: `PEATS_DEBUG=1 ~/Downloads/PeatsMac.app/Contents/MacOS/PeatsMac`

Credits: UI and app structure from [nothing-x-mac](https://github.com/farhancdr/nothing-x-mac) by farhancdr; protocol research by [PairFree](https://github.com/Omega-Destroyer/PairFree).
