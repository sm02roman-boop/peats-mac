## PeatsMac 0.4.0 — plain native UI

- New UI: a single scrolling panel with standard macOS controls and the system accent colour. No glass effects and no Nothing-style design.
- The menu bar item is back to the first release's: headphones icon with the battery percentage next to it.
- Everything the earbuds answer is still there: battery, noise control, game mode, dual connection, touch lock, light effect, dynamic EQ, movie mode, prompt volume and language, panoramic sound, touch controls, and the experimental equalizer and dual-connection device list.

**Install**
1. Download `PeatsMac.zip` below and unzip it.
2. In Terminal: `xattr -cr ~/Downloads/PeatsMac.app` (ad-hoc signed, not notarized).
3. Connect the T3 Pro in System Settings → Bluetooth, close PeatsAudio on your phone, then open PeatsMac and allow Bluetooth access.

Debug log: `PEATS_DEBUG=1 ~/Downloads/PeatsMac.app/Contents/MacOS/PeatsMac`

Credits: Bluetooth transport and app structure adapted from [nothing-x-mac](https://github.com/farhancdr/nothing-x-mac) by farhancdr; protocol research by [PairFree](https://github.com/Omega-Destroyer/PairFree).
