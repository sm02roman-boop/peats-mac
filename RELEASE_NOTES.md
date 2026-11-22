## PeatsMac 0.1.1

**Fixes**
- Earbuds renamed in macOS (for example "Sam's T3 Pro") are now recognised: the app matches the model name as well as "SOUNDPEATS".
- If the earbuds still aren't found, the panel lists your connected Bluetooth devices and lets you pick them; the choice is remembered.

A macOS menu bar app for SoundPEATS T3 Pro: battery, ANC / transparency, game mode, dual connection, touch controls, voice prompts, 8-band equalizer. Universal binary (Intel + Apple Silicon), macOS 13+.

**Install**
1. Download `PeatsMac.zip` below and unzip it.
2. In Terminal: `xattr -cr ~/Downloads/PeatsMac.app` (ad-hoc signed, not notarized).
3. Connect the T3 Pro in System Settings → Bluetooth, close PeatsAudio on your phone, then open PeatsMac and allow Bluetooth access.

**Status: early, not yet verified on real T3 Pro hardware.** Experimental: the equalizer and the "Dual connection devices" list.
To get a debug log: `PEATS_DEBUG=1 ~/Downloads/PeatsMac.app/Contents/MacOS/PeatsMac`

Credits: structure from [nothing-x-mac](https://github.com/farhancdr/nothing-x-mac) by farhancdr; protocol research by [PairFree](https://github.com/Omega-Destroyer/PairFree).
