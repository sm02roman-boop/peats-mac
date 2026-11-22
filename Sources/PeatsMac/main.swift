// PeatsMac: control SoundPEATS earbuds (built for the T3 Pro) from the menu bar.
// A status item opens a popover with the SwiftUI panel; right-click shows Quit.
// The Bluetooth transport and app structure are adapted from nothing-x-mac
// (MIT, see THIRD_PARTY_NOTICES.md).

import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let controller = DeviceController()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var subscription: AnyCancellable?
    private var lastClosedAt = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu bar only, no Dock icon

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "headphones", accessibilityDescription: "SoundPEATS")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: PanelView(controller: controller))

        subscription = controller.$state.sink { [weak self] state in
            self?.updateTitle(state)
        }
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Close the RFCOMM channel properly so the earbuds accept a new one next launch.
        controller.stop()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    }

    private func updateTitle(_ state: DeviceState) {
        guard state.connected else {
            statusItem?.button?.title = ""
            return
        }
        let levels = [state.battery.left, state.battery.right].compactMap { $0 }
        statusItem?.button?.title = levels.min().map { " \($0)%" } ?? ""
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            popover.performClose(nil)
            let menu = NSMenu()
            menu.addItem(withTitle: "Quit PeatsMac", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem?.menu = menu
            sender.performClick(nil)
            statusItem?.menu = nil
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else if Date().timeIntervalSince(lastClosedAt) > 0.25 {
            // A click on the icon closes the transient popover first; don't reopen it.
            controller.refreshBattery()
            controller.refreshCandidates()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        lastClosedAt = Date()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
