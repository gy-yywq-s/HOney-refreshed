// The handful of components built once (spec §7.5). No general "put
// everything in a card" container: rows are rows, hairlines part them.

import SwiftUI
import HOneyCore

/// The HOney wordmark: the Web's own PNG (solid ink glyphs on alpha),
/// rendered as a template so the night surface inverts it like the Web.
struct WordmarkView: View {
    var height: CGFloat = 30

    var body: some View {
        Image("Wordmark")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(570.0 / 191.0, contentMode: .fit)
            .frame(height: height)
            .foregroundStyle(Color.honeyInk)
            .accessibilityLabel("HOney")
    }
}

struct HairlineDivider: View {
    var body: some View {
        Rectangle().fill(Color.honeyLine).frame(height: 1)
    }
}

enum BannerTone { case info, success, warning, danger }

/// One-line status inside the content flow, never a floating toast.
struct InlineStatusBanner: View {
    let text: String
    var tone: BannerTone = .info
    var action: (label: String, run: () -> Void)?

    private var tint: Color {
        switch tone {
        case .info: return Color.honeyAccentTint
        case .success: return Color.honeySuccessTint
        case .warning: return Color.honeyWarningTint
        case .danger: return Color.honeyDangerTint
        }
    }

    private var ink: Color {
        switch tone {
        case .info: return Color.honeyInk
        case .success: return Color.honeySuccess
        case .warning: return Color.honeyWarning
        case .danger: return Color.honeyDanger
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: HSpace.x3) {
            Text(text)
                .font(HType.secondary)
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let action {
                Button(action.label, action: action.run)
                    .font(HType.secondary.weight(.semibold))
                    .foregroundStyle(ink)
            }
        }
        .padding(.horizontal, HSpace.x4)
        .padding(.vertical, HSpace.x3)
        .background(tint, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct EmptyStateView: View {
    let title: String
    var detail: String?
    var action: (label: String, run: () -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: HSpace.x2) {
            Text(title).font(HType.body.weight(.semibold)).foregroundStyle(Color.honeyInk)
            if let detail { Text(detail).font(HType.secondary).foregroundStyle(Color.honeySecondary) }
            if let action {
                Button(action.label, action: action.run)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, HSpace.x2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, HSpace.x4)
    }
}

/// Redacted placeholder lines that keep the geometry (spec §25.1).
struct LoadingPlaceholder: View {
    var lines: Int = 3

    var body: some View {
        VStack(alignment: .leading, spacing: HSpace.x2) {
            ForEach(0..<lines, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.honeySoft)
                    .frame(height: 14)
                    .frame(maxWidth: i == lines - 1 ? 180 : .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, HSpace.x2)
        .accessibilityLabel("Loading")
    }
}

/// Primary + optional secondary in a bottom action bar (composer, sheets).
struct PrimaryBottomActionBar: View {
    let primary: (label: String, run: () -> Void)
    var primaryEnabled = true
    var secondary: (label: String, run: () -> Void)?
    var secondaryEnabled = true

    var body: some View {
        HStack(spacing: HSpace.x3) {
            if let secondary {
                Button(secondary.label, action: secondary.run)
                    .buttonStyle(.bordered)
                    .disabled(!secondaryEnabled)
            }
            Button(primary.label, action: primary.run)
                .buttonStyle(.borderedProminent)
                .disabled(!primaryEnabled)
        }
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }
}

/// A plain navigation row: title, optional caption, disclosure.
struct EntityRow: View {
    let title: String
    var caption: String?
    var showsDisclosure = true

    var body: some View {
        HStack(spacing: HSpace.x3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(HType.body).foregroundStyle(Color.honeyInk)
                if let caption, !caption.isEmpty {
                    Text(caption).font(HType.meta).foregroundStyle(Color.honeySecondary)
                }
            }
            Spacer(minLength: HSpace.x2)
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.honeyTertiary)
            }
        }
        .padding(.vertical, HSpace.x3)
        .contentShape(Rectangle())
    }
}

/// A lesson as a row (History, target picker, unplaced Week lessons).
struct LessonRow: View {
    let lesson: Lesson
    var leading: String?
    var trailingTime = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: HSpace.x3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.subjectName).font(HType.body).foregroundStyle(Color.honeyInk)
                let parts = [leading, lesson.teacherName, DisplayNames.roomLabel(lesson.roomName)].compactMap { $0 }.filter { !$0.isEmpty }
                if !parts.isEmpty {
                    Text(parts.joined(separator: " · ")).font(HType.meta).foregroundStyle(Color.honeySecondary)
                }
            }
            Spacer(minLength: HSpace.x2)
            if trailingTime {
                Text(Formatters.time(lesson.startsAt))
                    .font(HType.meta.monospacedDigit())
                    .foregroundStyle(Color.honeySecondary)
            }
        }
        .padding(.vertical, HSpace.x3)
        .contentShape(Rectangle())
    }
}

/// Dish stars (display only; the only scalar rating in the product).
struct StarsView: View {
    let value: Int

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { n in
                Image(systemName: n <= value ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundStyle(n <= value ? Color.honeyAccent : Color.honeyLine)
            }
        }
        .accessibilityLabel("\(value) out of 5 stars")
    }
}

struct StarInput: View {
    @Binding var value: Int?

    var body: some View {
        HStack(spacing: HSpace.x2) {
            ForEach(1...5, id: \.self) { n in
                Button {
                    value = value == n ? nil : n
                } label: {
                    Image(systemName: (value ?? 0) >= n ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle((value ?? 0) >= n ? Color.honeyAccent : Color.honeyTertiary)
                        .frame(width: 36, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(n) star\(n > 1 ? "s" : "")")
                .accessibilityAddTraits(value == n ? .isSelected : [])
            }
            if value != nil {
                Button("Clear") { value = nil }.font(HType.meta)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dish rating (1 to 5 stars)")
    }
}

/// The Web's `.pageX` inset for content that lives in a ScrollView.
extension View {
    func pageInset() -> some View { padding(.horizontal, HSpace.pageX) }
}

/// A row-shaped button that presses like a list cell.
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.honeySoft : Color.clear)
    }
}
