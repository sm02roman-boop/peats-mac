// Controls page (touch gestures): pick the left or right bud, then a pop-up per gesture.
// Opened by clicking a bud on the main page. Layout follows nothing-x-mac.

import PeatsKit
import SwiftUI

struct ControlsView: View {
    let side: TouchSide
    @EnvironmentObject var device: DeviceController
    @EnvironmentObject var nav: PanelNavigation

    private static let slots: [(title: String, left: TouchGesture, right: TouchGesture)] = [
        ("Tap", .tapLeft, .tapRight),
        ("Double Tap", .doubleLeft, .doubleRight),
        ("Triple Tap", .tripleLeft, .tripleRight),
        ("Tap & Hold", .holdLeft, .holdRight),
    ]

    var body: some View {
        VStack(spacing: 0) {
            SubpageHeader(title: "Controls", back: .main)

            DotSegmented(items: TouchSide.allCases.map { SegmentItem(id: $0, label: $0.label) },
                         selection: side, height: 28, labelSize: 12) { nav.page = .controls($0) }
                .padding(.horizontal, Theme.inset)
                .padding(.top, 12)
                .padding(.bottom, 6)

            ForEach(Self.slots, id: \.title) { slot in
                GestureRow(title: slot.title, gesture: side == .left ? slot.left : slot.right)
            }

            FooterNote("Changes apply to the \(side.label) earbud only.")
                .padding(.top, 6)
                .padding(.bottom, 12)
        }
    }
}

private struct GestureRow: View {
    let title: String
    let gesture: TouchGesture
    @EnvironmentObject var device: DeviceController

    var body: some View {
        let current = device.state.keys[gesture]
        HStack(spacing: 10) {
            Image(systemName: "hand.tap").font(.system(size: 13)).foregroundStyle(Theme.secondaryLabel)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Picker(title, selection: Binding(
                get: { (current ?? .none).rawValue },
                set: { raw in
                    if let action = KeyAction(rawValue: raw) { device.setKey(gesture, action) }
                })) {
                ForEach(KeyAction.allCases) { action in
                    Text(action.label).tag(action.rawValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 132)
            .disabled(current == nil)
        }
        .padding(.horizontal, Theme.inset)
        .frame(minHeight: 40)
    }
}
