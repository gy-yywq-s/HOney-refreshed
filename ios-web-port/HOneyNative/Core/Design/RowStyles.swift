// Open row lists (features.css `.rowlist`, `.row`, `.entity-row`; fidelity
// spec v2 §4.6): page surface + hairlines, no grouping cards. A group is
// parted from the previous one by a rule above its label; rows inside a
// group sit on the surface without rules. Entity lists rule between rows.

import SwiftUI

/// `.rowlist`: a sentence-case label, then rows. `RowList` after `RowList`
/// draws the rule and the 16 pt gap itself when `first` is false.
struct RowList<Content: View>: View {
    @Environment(\.theme) private var theme
    var label: String?
    var first = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !first {
                HairlineDivider()
                Spacer().frame(height: HSpace.x4)
            }
            if let label {
                Text(label).sectionLabel().padding(.bottom, HSpace.x1)
            }
            content()
        }
        .padding(.bottom, HSpace.x1)
    }
}

enum RowTrailing {
    case none
    case chevron
    case action(String)
}

/// `.row`: 56 min, 12 pt vertical padding, title 600, caption sub, chevron.
struct SettingsRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let title: String
    var sub: String?
    var trailing: RowTrailing = .chevron
    var titleColor: Color?

    var body: some View {
        HStack(spacing: HSpace.x4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ramp.font(.bodySemibold))
                    .foregroundStyle(titleColor ?? theme.ink)
                if let sub, !sub.isEmpty {
                    Text(sub)
                        .font(ramp.font(.caption))
                        .lineSpacing(ramp.lineSpacing(.caption))
                        .foregroundStyle(theme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            switch trailing {
            case .none: EmptyView()
            case .chevron: ChevronGlyph()
            case .action(let text):
                Text(text).font(ramp.font(.captionSemibold)).foregroundStyle(theme.accent)
            }
        }
        .padding(.vertical, HSpace.x3)
        .frame(minHeight: HSize.row)
        .contentShape(Rectangle())
    }
}

/// `.row` with a custom trailing control (a switch, a small button).
struct ControlRow<Trailing: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let title: String
    var sub: String?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: HSpace.x4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(ramp.font(.bodySemibold)).foregroundStyle(theme.ink)
                if let sub, !sub.isEmpty {
                    Text(sub).font(ramp.font(.caption)).lineSpacing(ramp.lineSpacing(.caption)).foregroundStyle(theme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.vertical, HSpace.x3)
        .frame(minHeight: HSize.row)
    }
}

/// `.entity-row` (Explore, target picker): 56 min, 600 title, caption meta,
/// chevron; the caller rules between rows with `HairlineDivider`.
struct EntityRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let title: String
    var caption: String?
    var showsDisclosure = true

    var body: some View {
        HStack(spacing: HSpace.x3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(ramp.font(.bodySemibold)).foregroundStyle(theme.ink)
                if let caption, !caption.isEmpty {
                    Text(caption).font(ramp.font(.caption)).foregroundStyle(theme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsDisclosure { ChevronGlyph() }
        }
        .padding(.vertical, HSpace.x3)
        .frame(minHeight: HSize.row)
        .contentShape(Rectangle())
    }
}

/// The Web's 18 px chevron glyph in `--ink-3`.
struct ChevronGlyph: View {
    @Environment(\.theme) private var theme
    var size: CGFloat = 18

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: size * 0.72, weight: .medium))
            .foregroundStyle(theme.ink3)
            .frame(width: size, height: size)
    }
}

/// `.disclosure`: a summary line in the accent that folds a caption open.
struct DisclosureRow<Content: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let summary: String
    @State private var open = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HairlineDivider()
            Button {
                withAnimation(.easeOut(duration: 0.2)) { open.toggle() }
            } label: {
                HStack {
                    Text(summary).font(ramp.font(.bodySemibold)).foregroundStyle(theme.accent)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.accent)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .frame(minHeight: HSize.control)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(open ? [.isSelected] : [])
            if open {
                content().padding(.bottom, HSpace.x2)
            }
        }
        .padding(.vertical, HSpace.x2)
    }
}
