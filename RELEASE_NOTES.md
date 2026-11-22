## PeatsMac 0.1.0 — first release (SoundPEATS T3 Pro)

A macOS menu bar app for SoundPEATS T3 Pro: battery, ANC / transparency, game mode, dual connection,
touch controls, voice prompts, 8-band equalizer. Universal binary (Intel + Apple Silicon), macOS 13+.

**Install**
1. Download `PeatsMac.zip` below and unzip it.
2. In Terminal: `xattr -cr ~/Downloads/PeatsMac.app` (the app is ad-hoc signed, not notarized).
3. Connect the T3 Pro in System Settings → Bluetooth, close PeatsAudio on your phone, then open PeatsMac and allow Bluetooth access.

**Status: early, not yet verified on real T3 Pro hardware.** The protocol layer passes its self-checks on CI,
and the T3 Pro command set comes from a real device probe published by PairFree, but nobody has run this app against the earbuds yet.
Experimental: the equalizer and the "Dual connection devices" list. Please report what works with `PEATS_DEBUG=1` logs.

Credits: structure from [nothing-x-mac](https://github.com/farhancdr/nothing-x-mac) by farhancdr; protocol research by [PairFree](https://github.com/Omega-Destroyer/PairFree).
