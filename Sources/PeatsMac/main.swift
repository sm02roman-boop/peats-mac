// PeatsMac: control SoundPEATS earbuds (built for the T3 Pro) from the menu bar.
// A status item opens a popover with the SwiftUI panel; right-click shows Quit.
// App structure follows nothing-x-mac (MIT, see THIRD_PARTY_NOTICES.md).

import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    static let appName = "PeatsMac"

    private let controller = DeviceController()
    private let navigation = PanelNavigation()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private var lastClosedAt = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu bar only, no Dock icon

        let panel = PanelView()
            .environmentObject(controller)
            .environmentObject(navigation)
        let hosting = NSHostingController(rootView: panel)
        hosting.sizingOptions = .preferredContentSize // popover follows the panel's height
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = Self.menuBarIcon()
            button.imagePosition = .imageLeading
            button.toolTip = Self.appName
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Keep the menu bar title and tooltip in sync with the earbuds.
        controller.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.updateStatusItem(state: state) }
            .store(in: &cancellables)

        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Close the RFCOMM channel properly, or the earbuds refuse the next connection.
        controller.stop()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    }

    private func updateStatusItem(state: DeviceState) {
        guard let button = statusItem?.button else { return }
        button.appearsDisabled = !state.connected // dimmed until the earbuds are connected
        // "82·79": left and right battery, like nothing-x-mac. SF 12 medium with tabular digits.
        var text: String?
        if state.connected, state.battery.left != nil || state.battery.right != nil {
            let left = state.battery.left.map(String.init) ?? "–"
            let right = state.battery.right.map(String.init) ?? "–"
            text = "\(left)·\(right)"
        }
        button.attributedTitle = NSAttributedString(
            string: text.map { "\u{2009}\($0)" } ?? "",
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)])
        button.toolTip = state.connected ? "\(Self.appName) · \(state.name ?? "")" : Self.appName
    }

    /// The AirPods Pro symbol, drawn as a template so macOS tints it for light and dark menu bars.
    static func menuBarIcon() -> NSImage? {
        let image = NSImage(systemSymbolName: "airpodspro", accessibilityDescription: "SoundPEATS")
        image?.isTemplate = true
        return image
    }

    // MARK: Popover

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            popover.performClose(nil)
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if Date().timeIntervalSince(lastClosedAt) > 0.25 {
            // A click on the icon closes the transient popover first; don't reopen it.
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        controller.refreshBattery()
        controller.refreshCandidates()
        navigation.page = .main
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) {
        lastClosedAt = Date()
        navigation.page = .main
    }

    // MARK: Context menu

    private func showContextMenu() {
        let menu = NSMenu()
        let quit = NSMenuItem(title: "Quit \(Self.appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        // Attach temporarily so the menu drops down from the icon like a normal menu.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
