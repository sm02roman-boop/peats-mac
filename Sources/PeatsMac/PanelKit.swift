// The popover panel: the main page plus sub-pages that slide in from the right,
// and the building blocks they share. Layout, sizes and colours are the nothing-x-mac
// design (MIT, see THIRD_PARTY_NOTICES.md), applied to SoundPEATS controls.

import PeatsKit
import SwiftUI

enum TouchSide: String, CaseIterable, Identifiable {
    case left, right
    var id: String { rawValue }
    var label: String { self == .left ? "Left" : "Right" }
}

enum PanelPage: Equatable {
    case main, quickSettings, dual, equalizer
    case controls(TouchSide)
}

final class PanelNavigation: ObservableObject {
    @Published var page: PanelPage = .main
}

struct PanelView: View {
    static let width = Theme.panelWidth

    @EnvironmentObject var device: DeviceController
    @EnvironmentObject var nav: PanelNavigation

    var body: some View {
        ZStack {
            switch nav.page {
            case .main:
                MainView().transition(.move(edge: .leading).combined(with: .opacity))
            case .quickSettings:
                QuickSettingsView().transition(.move(edge: .trailing).combined(with: .opacity))
            case .dual:
                DualConnectionView().transition(.move(edge: .trailing).combined(with: .opacity))
            case .equalizer:
                EqualizerView().transition(.move(edge: .trailing).combined(with: .opacity))
            case .controls(let side):
                ControlsView(side: side).transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: Self.width)
        .foregroundStyle(Theme.label)
        .panelAccent(system: false)
        .animation(.easeOut(duration: 0.2), value: nav.page)
        .background(
            // Esc goes back one level.
            Button("") { nav.page = nav.page.parent }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
        )
        .onChange(of: device.state.connected) { connected in
            if !connected { nav.page = .main }
        }
    }
}

extension PanelPage {
    var parent: PanelPage {
        switch self {
        case .dual: return .quickSettings
        default: return .main
        }
    }
}

// MARK: - Structure

/// 1 pt full-width line between sections.
struct PanelSeparator: View {
    var body: some View {
        Rectangle().fill(Theme.separator).frame(height: 1)
    }
}

/// 11 pt semibold caption above a group of controls.
struct SectionCaption: View {
    let text: String
    var trailing: String?
    init(_ text: String, trailing: String? = nil) {
        self.text = text
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(text).font(.system(size: 11, weight: .semibold))
            if let trailing {
                Text("·")
                Text(trailing).font(.system(size: 11, weight: .semibold))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.secondaryLabel)
        .padding(.horizontal, Theme.inset)
        .padding(.bottom, 8)
    }
}

/// Back chevron + title for sub-pages (44 pt), with an optional trailing control.
struct SubpageHeader<Trailing: View>: View {
    let title: String
    var back: PanelPage?
    @ViewBuilder var trailing: () -> Trailing
    @EnvironmentObject var nav: PanelNavigation

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                Button { nav.page = back ?? nav.page.parent } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.secondaryLabel)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Back")
                .accessibilityLabel("Back")
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
                trailing()
            }
            .padding(.leading, 6)
            .padding(.trailing, Theme.inset)
            .frame(height: 44)
            PanelSeparator()
        }
    }
}

extension SubpageHeader where Trailing == EmptyView {
    init(title: String, back: PanelPage? = nil) {
        self.title = title
        self.back = back
        self.trailing = { EmptyView() }
    }
}

struct FooterNote: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Theme.secondaryLabel)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.inset)
    }
}

/// Rounded info box (tips, limits, warnings).
struct TipBox: View {
    var symbol = "info.circle"
    var bold: String?
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).font(.system(size: 12)).foregroundStyle(Theme.secondaryLabel)
            (bold.map { Text($0 + " ").fontWeight(.semibold).foregroundColor(Theme.label) } ?? Text(""))
                + Text(text).foregroundColor(Theme.secondaryLabel)
        }
        .font(.system(size: 11))
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.controlFill))
    }
}

// MARK: - Controls

/// Small spinner for "waiting for the buds to confirm" (secondary tint, never accent).
struct PendingSpinner: View {
    var size: CGFloat = 13
    var body: some View {
        ProgressView()
            .controlSize(.small)
            .scaleEffect(size / 16)
            .frame(width: size, height: size)
            .tint(Theme.secondaryLabel)
    }
}

/// 26×26 icon button in the main header.
struct HeaderIconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @StateObject private var hovering = Local(false)

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryLabel)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 6)
                    .fill(hovering.value ? Theme.controlFillStrong : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .onHover { hovering.value = $0 }
    }
}

/// One option of a `DotSegmented` control.
struct SegmentItem<ID: Hashable>: Identifiable {
    let id: ID
    let label: String
    var symbol: String?
}

/// Segmented control from the design: a track with a raised white thumb. The
/// selected icon takes the accent; a pending option shows a spinner instead
/// of its icon while the others dim.
struct DotSegmented<ID: Hashable>: View {
    let items: [SegmentItem<ID>]
    let selection: ID?
    var pending = false
    var height: CGFloat = 46
    var labelSize: CGFloat = 11
    let onSelect: (ID) -> Void
    @Environment(\.accent) private var accent

    var body: some View {
        let radius: CGFloat = height >= 40 ? 9 : 8
        HStack(spacing: 0) {
            ForEach(items) { item in
                let selected = item.id == selection
                Button { if !pending { onSelect(item.id) } } label: {
                    VStack(spacing: 3) {
                        if let symbol = item.symbol {
                            if selected && pending {
                                PendingSpinner(size: 14).frame(height: 16)
                            } else {
                                Image(systemName: symbol)
                                    .font(.system(size: 14))
                                    .foregroundStyle(selected ? accent : Theme.secondaryLabel)
                                    .frame(height: 16)
                            }
                        }
                        HStack(spacing: 4) {
                            if item.symbol == nil && selected && pending { PendingSpinner(size: 10) }
                            Text(item.label)
                                .font(.system(size: labelSize, weight: selected ? .semibold : .medium))
                                .foregroundStyle(selected ? Theme.label : Theme.secondaryLabel)
                                .lineLimit(1)
                                .minimumScaleFactor(item.symbol == nil ? 1 : 0.8)
                                // Text-only segments keep their size; a long label widens its segment.
                                .fixedSize(horizontal: item.symbol == nil, vertical: false)
                        }
                        .padding(.horizontal, 7) // keeps labels off the thumb's edges
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: radius - 2)
                            .fill(selected ? Theme.selectedSegment : .clear)
                            .shadow(color: selected ? Theme.segmentShadow : .clear, radius: 0.75, y: 0.5)
                    )
                    .opacity(pending && !selected ? 0.5 : 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: radius).fill(Theme.controlFill))
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: selection)
    }
}

/// Primary (accent fill, white label) or secondary (controlFillStrong) 28 pt button.
struct PanelButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.accentFill) private var accentFill
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(primary ? Color.white : Theme.label)
            .padding(.horizontal, 12)
            .frame(minHeight: 28)
            .background(RoundedRectangle(cornerRadius: 6)
                .fill(primary ? accentFill : Theme.controlFillStrong))
            .opacity(configuration.isPressed ? 0.75 : enabled ? 1 : 0.55)
            .contentShape(Rectangle())
    }
}

/// A list row (preset, spatial mode): checkmark in accent, selected row filled.
struct SelectRow: View {
    let label: String
    var detail: String?
    let selected: Bool
    var pending = false
    var height: CGFloat = 28
    let action: () -> Void
    @Environment(\.accent) private var accent
    @StateObject private var hovering = Local(false)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Group {
                    if pending {
                        PendingSpinner(size: 11)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accent)
                            .opacity(selected ? 1 : 0)
                    }
                }
                .frame(width: 14)
                Text(label).font(.system(size: 13)).lineLimit(1)
                Spacer(minLength: 4)
                if let detail {
                    Text(detail).font(.system(size: 11).monospacedDigit()).foregroundStyle(Theme.secondaryLabel)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 6)
                .fill(selected ? Theme.controlFill : hovering.value ? Theme.controlFill.opacity(0.6) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .onHover { hovering.value = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A full-width row that highlights on hover, like menu items.
struct HoverRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverRow(configuration: configuration)
    }

    private struct HoverRow: View {
        let configuration: ButtonStyle.Configuration
        @StateObject private var hovering = Local(false)
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .contentShape(Rectangle())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hovering.value && enabled ? Theme.controlFill : .clear)
                )
                .padding(.horizontal, 6)
                .opacity(enabled ? 1 : 0.45)
                .onHover { hovering.value = $0 }
        }
    }
}

/// View-local state. Stands in for @State, which is a macro in the current SDK
/// whose plugin only ships with Xcode, not the Command Line Tools.
final class Local<Value>: ObservableObject {
    @Published var value: Value
    init(_ value: Value) { self.value = value }
}
