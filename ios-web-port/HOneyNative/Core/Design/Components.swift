// The handful of components built once, in the Web's grammar (components.css,
// foundations.css): wordmark, hairline, banners, empty state, skeleton,
// stars, page titles. Rows are rows, hairlines part them; nothing is a
// grouped card unless the Web draws one.

import SwiftUI
import HOneyCore

/// The HOney wordmark: the Web's own PNG (solid ink glyphs on alpha),
/// rendered as a template so Night inverts it like the Web.
struct WordmarkView: View {
    @Environment(\.theme) private var theme
    var height: CGFloat = 30

    var body: some View {
        Image("Wordmark")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(570.0 / 191.0, contentMode: .fit)
            .frame(height: height)
            .foregroundStyle(theme.ink)
            .accessibilityLabel("HOney")
    }
}

struct HairlineDivider: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Rectangle().fill(theme.line).frame(height: 1)
    }
}

/// `.page-title`: 30 pt, 650, -0.015em (the h1 of a root or pushed screen).
struct PageTitle: View {
    @Environment(\.theme) private var theme
    let text: String

    var body: some View {
        Text(text)
            .hfont(.pageTitle)
            .foregroundStyle(theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// `.section-title`: 20 pt, 650.
struct SectionTitle: View {
    @Environment(\.theme) private var theme
    let text: String

    var body: some View {
        Text(text).hfont(.sectionTitle).foregroundStyle(theme.ink).accessibilityAddTraits(.isHeader)
    }
}

enum BannerTone { case info, success, warning, danger }

/// `.banner`: line border, field radius, tinted ground, semantic ink, the
/// inline action as a small ghost button. Never a floating toast.
struct InlineStatusBanner: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let text: String
    var tone: BannerTone = .info
    var action: (label: String, run: () -> Void)?

    private var ink: Color {
        switch tone {
        case .info: return theme.inkSoft
        case .success: return theme.ok
        case .warning: return theme.accent
        case .danger: return theme.danger
        }
    }

    private var ground: Color {
        switch tone {
        case .info: return theme.soft
        case .success: return theme.tint(theme.palette.ok, 0.08)
        case .warning: return theme.tint(theme.palette.accent, 0.08)
        case .danger: return theme.tint(theme.palette.danger, 0.08)
        }
    }

    private var border: Color {
        switch tone {
        case .info: return theme.line
        case .success: return theme.tint(theme.palette.ok, 0.38)
        case .warning: return theme.tint(theme.palette.accent, 0.38)
        case .danger: return theme.tint(theme.palette.danger, 0.38)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: HSpace.x3) {
            Text(text)
                .font(ramp.font(.body))
                .lineSpacing(ramp.lineSpacing(.body))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let action {
                Button(action.label, action: action.run).buttonStyle(.webSmallGhost)
            }
        }
        .padding(.horizontal, HSpace.x4)
        .padding(.vertical, HSpace.x3)
        .background(ground, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).strokeBorder(border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// `.feed-empty`: a strong line, a muted line, one primary action.
struct EmptyStateView: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let title: String
    var detail: String?
    var action: (label: String, run: () -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: HSpace.x2) {
            Text(title).font(ramp.font(.bodySemibold)).foregroundStyle(theme.ink)
            if let detail { Text(detail).font(ramp.font(.body)).foregroundStyle(theme.muted) }
            if let action {
                Button(action.label, action: action.run).buttonStyle(.webPrimary).padding(.top, HSpace.x2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, HSpace.x7)
    }
}

/// `.skeleton`: quiet 14 pt bars, pill radius, soft ground.
struct LoadingPlaceholder: View {
    @Environment(\.theme) private var theme
    var lines: Int = 3

    var body: some View {
        VStack(alignment: .leading, spacing: HSpace.x3) {
            ForEach(0..<lines, id: \.self) { i in
                Capsule()
                    .fill(theme.soft)
                    .frame(height: 14)
                    .frame(maxWidth: i == lines - 1 ? 180 : .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, HSpace.x1)
        .accessibilityLabel("Loading")
    }
}

/// `.compose-actions` on phones: full-width buttons stacked, primary first.
struct PrimaryBottomActionBar: View {
    let primary: (label: String, run: () -> Void)
    var primaryEnabled = true
    var secondary: (label: String, run: () -> Void)?
    var secondaryEnabled = true

    var body: some View {
        VStack(spacing: HSpace.x2) {
            Button(primary.label, action: primary.run)
                .buttonStyle(.webBlockPrimary)
                .disabled(!primaryEnabled)
            if let secondary {
                Button(secondary.label, action: secondary.run)
                    .buttonStyle(.webBlockGhost)
                    .disabled(!secondaryEnabled)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// A lesson as a row (History, target picker, unplaced Week lessons):
/// `.history-row` / `.entity-row` grammar.
struct LessonRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let lesson: Lesson
    var leading: String?
    var trailingTime = true

    var body: some View {
        HStack(alignment: .center, spacing: HSpace.x4) {
            VStack(alignment: .leading, spacing: HSpace.x1) {
                Text(lesson.subjectName).font(ramp.font(.bodySemibold)).foregroundStyle(theme.ink)
                let parts = [leading, lesson.teacherName, DisplayNames.roomLabel(lesson.roomName)].compactMap { $0 }.filter { !$0.isEmpty }
                if !parts.isEmpty {
                    Text(parts.joined(separator: " · ")).font(ramp.font(.caption)).foregroundStyle(theme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if trailingTime {
                Text(Formatters.time(lesson.startsAt))
                    .font(ramp.font(.secondarySemibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.ink2)
            }
        }
        .padding(.vertical, HSpace.x3)
        .frame(minHeight: HSize.row)
        .contentShape(Rectangle())
    }
}

/// `.stars`: ★ glyphs in the accent, empties at 26% (dishes only).
struct StarsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let value: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { n in
                Text("★")
                    .font(ramp.font(.caption))
                    .foregroundStyle(theme.accent)
                    .opacity(n <= value ? 1 : 0.26)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) out of 5 stars")
    }
}

/// `.star-input`: 24 pt stars, line ink off, accent on, 44 pt targets.
struct StarInput: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @Binding var value: Int?

    var body: some View {
        HStack(spacing: HSpace.x1) {
            ForEach(1...5, id: \.self) { n in
                Button {
                    value = value == n ? nil : n
                } label: {
                    Text("★")
                        .font(.system(size: 24))
                        .foregroundStyle((value ?? 0) >= n ? theme.accent : theme.line)
                        .frame(width: HSize.control, height: HSize.control)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(n) star\(n > 1 ? "s" : "")")
                .accessibilityAddTraits(value == n ? .isSelected : [])
            }
            if value != nil {
                Button("Clear") { value = nil }.buttonStyle(.webLink)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dish rating (1 to 5 stars)")
    }
}

/// `.chip`: a small status pill (Notes & Posts statuses).
struct StatusChip: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let text: String
    var ink: Color?
    var ground: Color?
    var dashed = false

    var body: some View {
        Text(text)
            .font(ramp.font(.microSemibold))
            .foregroundStyle(ink ?? theme.accent)
            .padding(.horizontal, HSpace.x3)
            .padding(.vertical, HSpace.x1)
            .background(dashed ? Color.clear : (ground ?? theme.soft), in: Capsule())
            .overlay {
                if dashed { Capsule().strokeBorder(theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3])) }
            }
    }
}

extension View {
    /// The Web's `--page-x` inset for content that lives in a ScrollView.
    func pageInset() -> some View { padding(.horizontal, HSpace.pageX) }

    /// The page ground for every screen: the chosen surface, edge to edge.
    func surfaceBackground() -> some View { modifier(SurfaceBackground()) }

    /// A pushed screen's chrome, like the Web's `.pagebar`: only "‹ Parent"
    /// in the bar (the title names the screen for the next back button; a
    /// principal item keeps it out of the bar itself), the page title in
    /// content, no system large title.
    func webScreen(title: String) -> some View {
        self.navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) } }
            .toolbar(.hidden, for: .tabBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .surfaceBackground()
    }
}

private struct SurfaceBackground: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(theme.surface.ignoresSafeArea())
    }
}
