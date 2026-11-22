// Menu bar and panel icon: earbuds, falling back to older SF Symbols on macOS versions that lack it.

import AppKit

enum AppIcons {
    static func earbuds() -> NSImage {
        for name in ["earbuds", "airpodspro", "waveform"] {
            if let image = NSImage(systemSymbolName: name, accessibilityDescription: "SoundPEATS") {
                image.isTemplate = true
                return image
            }
        }
        return NSImage()
    }
}
