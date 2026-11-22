// PeatsMac: a menu bar app for SoundPEATS earbuds (built for the T3 Pro).

import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = DeviceController()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var subscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        popover.contentViewController = NSHostingController(rootView: PanelView(controller: controller))

        subscription = controller.$state.sink { [weak self] state in
            self?.updateTitle(state)
        }
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Close the RFCOMM channel properly so the earbuds accept a new one next launch.
        controller.stop()
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
            let menu = NSMenu()
            menu.addItem(withTitle: "Quit PeatsMac", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem?.menu = menu
            sender.performClick(nil)
            statusItem?.menu = nil
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
