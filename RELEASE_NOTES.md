## PeatsMac 0.3.0 — Glass

The whole panel is restyled as glassmorphism. Layout, pages and behaviour are unchanged from 0.2.0, and the menu bar item (Dot Bud icon and `82·79`) is the same.

- Frosted background with soft coloured glows behind the glass.
- Blurred glass cards for battery, tiles, tips, buttons and the segmented control, with a bright rim light and soft shadows.
- The "Unverified model" notice is gone.

**Install**
1. Download `PeatsMac.zip` below and unzip it.
2. In Terminal: `xattr -cr ~/Downloads/PeatsMac.app` (ad-hoc signed, not notarized).
3. Connect the T3 Pro in System Settings → Bluetooth, close PeatsAudio on your phone, then open PeatsMac and allow Bluetooth access.

Debug log: `PEATS_DEBUG=1 ~/Downloads/PeatsMac.app/Contents/MacOS/PeatsMac`

Credits: UI and app structure from [nothing-x-mac](https://github.com/farhancdr/nothing-x-mac) by farhancdr; protocol research by [PairFree](https://github.com/Omega-Destroyer/PairFree).
