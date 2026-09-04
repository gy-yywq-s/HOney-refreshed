// Home (HomePage.tsx + features.css `.home-*`, `.nextlesson*`, `.portal-row`;
// fidelity spec v2 §6): brand bar → greeting + date → the Now/Next card in
// its 150 pt slot → From your classes (1–2 raw previews, the composer
// prompt inside the zone) → the School Portal row. Zones part with a
// hairline; no avatars, no last-updated, no refresh control — pull to refresh.

import SwiftUI
import HOneyCore

struct HomeView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var model: HomeViewModel?
    @State private var showPortal = false

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height <= 700
            ScrollView {
                VStack(alignment: .leading, spacing: HSpace.x4) {
                    if let me = env.me {
                        HStack(alignment: .top, spacing: HSpace.x3) {
                            VStack(alignment: .leading, spacing: HSpace.x1) {
                                Text(L10n.greeting(me.displayName))
                                    .hfont(.greeting)
                                    .foregroundStyle(theme.ink)
                                    .accessibilityAddTraits(.isHeader)
                                Text(Formatters.dayTitle(Formatters.todayIsoDate()))
                                    .hfont(.secondary)
                                    .foregroundStyle(theme.ink2)
                            }
                            Spacer(minLength: HSpace.x2)
                            WordmarkView(height: 22)
                                .padding(.top, 3)
                        }
                        .pageInset()
                        .padding(.top, HSpace.x5)
                    }

                    if let model {
                        lessonRegion(model, compact: compact)
                            .frame(minHeight: 150, alignment: .top)
                            .pageInset()
                        voicesRegion(model, previewCount: compact ? 1 : 2, lineLimit: compact ? 2 : 3)
                            .pageInset()
                    } else {
                        LoadingPlaceholder(lines: 2).pageInset()
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        HairlineDivider()
                        PortalRow { showPortal = true }
                            .padding(.top, HSpace.x4)
                    }
                    .pageInset()
                }
                .frame(minHeight: geo.size.height, alignment: .top)
                .padding(.bottom, HSpace.x4)
            }
            .honeyRefreshable { await model?.load(reload: true) }
        }
        .surfaceBackground()
        .toolbar(.hidden, for: .navigationBar)
        .navigationTitle("Home")
        .task {
            if model == nil { model = HomeViewModel(env: env) }
            await model?.load()
        }
        .fullScreenCover(isPresented: $showPortal) { PortalView() }
    }

    @ViewBuilder
    private func lessonRegion(_ model: HomeViewModel, compact: Bool) -> some View {
        if model.lessonLoading, model.nextLesson == nil {
            NowNextLessonCard.placeholder(compact: compact)
        } else if let error = model.lessonError, model.nextLesson == nil {
            InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await model.load(reload: true) } }))
                .frame(maxHeight: .infinity)
        } else if let next = model.nextLesson?.nextLesson {
            NowNextLessonCard(next: next, compact: compact) {
                nav.timetableIntent = TimetableIntent(date: Formatters.toIsoDate(Date(epochMillis: next.lesson.startsAt)), view: .day)
                nav.go(.timetable)
            }
        } else {
            NowNextLessonCard.empty(compact: compact) { nav.go(.timetable) }
        }
    }

    /// `.home-voices.home-zone`: rule above, 16 pt in, the label, the rows,
    /// the composer prompt. Reserves 132 pt so nothing shifts when it resolves.
    @ViewBuilder
    private func voicesRegion(_ model: HomeViewModel, previewCount: Int, lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HairlineDivider()
            Text(L10n.t("From your classes"))
                .sectionLabel()
                .padding(.top, HSpace.x4)
                .padding(.bottom, HSpace.x2)

            if model.previewsLoading, model.previews.isEmpty {
                LoadingPlaceholder(lines: 2)
            } else if let error = model.previewsError, model.previews.isEmpty {
                // A failed request is not an empty community.
                InlineStatusBanner(text: error, tone: .warning, action: (L10n.t("Try again"), { Task { await model.load(reload: true) } }))
            } else if model.previews.isEmpty {
                Text(L10n.t("When someone shares an experience connected to your classes, it will appear here."))
                    .hfont(.body)
                    .foregroundStyle(theme.muted)
                    .padding(.top, HSpace.x2)
            } else {
                let shown = Array(model.previews.prefix(previewCount))
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, exp in
                    ExperiencePreviewRow(exp: exp, lineLimit: lineLimit) {
                        nav.experiencesIntent = ExperiencesIntent(scope: .myClasses, anchorId: exp.id)
                        nav.go(.experiences)
                    }
                    if index < shown.count - 1 { HairlineDivider() }
                }
            }

            ComposerPromptRow { nav.go(.experiences, [.compose(nil)]) }
                .padding(.top, HSpace.x3)
        }
        .frame(minHeight: 132, alignment: .top)
    }
}

/// `.card.card--hero.nextlesson`: one temporal header (state left, relative
/// time right), the subject at 25/600, exact time then teacher · room, the
/// chevron centred at the right; a running lesson fills the card from the
/// left with the scheme's companion colour at 22 %.
struct NowNextLessonCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let next: NextLesson
    var compact = false
    let open: () -> Void

    var body: some View {
        // Cadence: the clock text and fill step every 30 s; nothing interpolates.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let p = HomeLessonPresentation(next, now: context.date)
            Button(action: open) {
                HeroCard(compact: compact, progress: p.progress) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: HSpace.x3) {
                            Text(p.stateLabel)
                                .font(ramp.font(.captionSemibold))
                                .foregroundStyle(theme.ink2)
                            Spacer(minLength: 0)
                            Text(p.when)
                                .font(ramp.font(.captionSemibold))
                                .monospacedDigit()
                                .lineLimit(1)
                                .foregroundStyle(p.soon ? theme.ink : theme.accent)
                                .padding(.horizontal, p.soon ? HSpace.x2 : 0)
                                .padding(.vertical, p.soon ? 2 : 0)
                                .background(p.soon ? theme.accentTint : Color.clear, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
                        }
                        Text(p.subject)
                            .hfont(.lessonSubject)
                            .foregroundStyle(theme.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .padding(.top, HSpace.x4)
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline, spacing: HSpace.x4) {
                                timeText(p)
                                whoLine(p)
                            }
                            VStack(alignment: .leading, spacing: HSpace.x1) {
                                timeText(p)
                                whoLine(p)
                            }
                        }
                        .padding(.top, HSpace.x3)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(p.accessibilityLabel)
        }
    }

    private func timeText(_ p: HomeLessonPresentation) -> some View {
        Text(p.timeRange)
            .font(ramp.font(.bodySemibold))
            .monospacedDigit()
            .foregroundStyle(theme.ink)
            .fixedSize()
    }

    @ViewBuilder
    private func whoLine(_ p: HomeLessonPresentation) -> some View {
        if p.teacher != nil || p.room != nil {
            HStack(alignment: .firstTextBaseline, spacing: HSpace.x3) {
                if let teacher = p.teacher {
                    Text(teacher).font(ramp.font(.secondary)).foregroundStyle(theme.ink2)
                }
                Spacer(minLength: 0)
                if let room = p.room {
                    Text(room).font(ramp.font(.secondary)).foregroundStyle(theme.ink2).lineLimit(1)
                }
            }
        }
    }

    /// Geometry-preserving placeholder while the first load runs.
    static func placeholder(compact: Bool) -> some View {
        PlaceholderCard(compact: compact)
    }

    /// `.nextlesson--empty`: the label, then one quiet sentence at 17/500.
    static func empty(compact: Bool, open: @escaping () -> Void) -> some View {
        EmptyCard(compact: compact, open: open)
    }

    private struct PlaceholderCard: View {
        @Environment(\.theme) private var theme
        @Environment(\.hType) private var ramp
        let compact: Bool

        var body: some View {
            HeroCard(compact: compact, progress: nil) {
                VStack(alignment: .leading, spacing: HSpace.x4) {
                    Text(L10n.t("Next lesson")).font(ramp.font(.captionSemibold)).foregroundStyle(theme.ink2)
                    LoadingPlaceholder(lines: 2)
                }
            }
            .accessibilityLabel("Loading")
        }
    }

    private struct EmptyCard: View {
        @Environment(\.theme) private var theme
        @Environment(\.hType) private var ramp
        let compact: Bool
        let open: () -> Void

        var body: some View {
            Button(action: open) {
                HeroCard(compact: compact, progress: nil) {
                    VStack(alignment: .leading, spacing: HSpace.x2) {
                        Text(L10n.t("Nothing coming up")).font(ramp.font(.captionSemibold)).foregroundStyle(theme.ink2)
                        Text(L10n.t("No upcoming lessons in your timetable."))
                            .font(ramp.font(.readingSemibold))
                            .fontWeight(.medium)
                            .foregroundStyle(theme.ink2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(L10n.t("Nothing coming up")). Open timetable")
        }
    }
}

/// `.card--hero` + `.nextlesson` geometry: surface-solid, 18 pt radius,
/// 1 px line, the Web shadow, 20 pt in (16 on compact heights), 44 pt of
/// trailing clearance for the centred chevron, the wash behind everything.
private struct HeroCard<Content: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let compact: Bool
    let progress: Double?
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, HSpace.x5)
            .padding(.trailing, HSpace.x8)
            .padding(.vertical, compact ? HSpace.x4 : HSpace.x5)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background {
                ZStack(alignment: .leading) {
                    theme.surfaceSolid
                    if let progress {
                        GeometryReader { geo in
                            theme.progressWash
                                .frame(width: geo.size.width * progress)
                        }
                        .transaction { $0.animation = nil } // steps once per tick, never interpolates
                    }
                }
            }
            .overlay(alignment: .trailing) {
                ChevronGlyph().padding(.trailing, HSpace.x4)
            }
            .clipShape(RoundedRectangle(cornerRadius: HRadius.hero, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HRadius.hero, style: .continuous).strokeBorder(theme.line, lineWidth: 1))
            .shadow(color: theme.shadow, radius: 20, y: 14)
            .contentShape(RoundedRectangle(cornerRadius: HRadius.hero, style: .continuous))
    }
}

/// `.home-voices__row`: the words at 15/1.5 (3 lines; 2 on compact), then
/// course · teacher · day as a caption.
struct ExperiencePreviewRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let exp: PublicExperience
    var lineLimit = 3
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: HSpace.x1) {
                Text(exp.body ?? "")
                    .font(ramp.font(.secondary))
                    .lineSpacing(ramp.lineSpacing(.secondary))
                    .foregroundStyle(theme.ink)
                    .lineLimit(lineLimit)
                    .multilineTextAlignment(.leading)
                let caption = ExperienceDisplay.previewCaption(exp)
                if !caption.isEmpty {
                    Text(caption).font(ramp.font(.caption)).foregroundStyle(theme.muted).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, HSpace.x3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// `.composer-prompt`: a field-shaped entry at the foot of the voices — pen
/// glyph in the accent, the prompt in ink-2, cell ground, line border.
struct ComposerPromptRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: HSpace.x3) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(theme.accent)
                Text(L10n.t("Share what a lesson was like…"))
                    .font(ramp.font(.secondary))
                    .foregroundStyle(theme.ink2)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, HSpace.x4)
            .padding(.vertical, HSpace.x3)
            .frame(minHeight: HSize.control)
            .background(theme.cell, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).strokeBorder(theme.line, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("Share an experience"))
    }
}

/// `.portal-row`: one bordered row — the portal's own mark (inverted on
/// Night), "School Portal", then "Open the official site ↗" as a caption.
struct PortalRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: HSpace.x3) {
                Image("OASIS")
                    .resizable()
                    .frame(width: 22, height: 22)
                    .clipShape(Circle())
                    .colorInvert(if: theme.isNight)
                    .accessibilityHidden(true)
                Text("School Portal")
                    .font(ramp.font(.body))
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(L10n.t("Open the official site")) ↗")
                    .font(ramp.font(.caption))
                    .foregroundStyle(theme.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, HSpace.x4)
            .padding(.vertical, HSpace.x3)
            .background(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).strokeBorder(theme.line, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("School Portal, \(L10n.t("Open the official site"))")
    }
}

private extension View {
    @ViewBuilder
    func colorInvert(if condition: Bool) -> some View {
        if condition { self.colorInvert() } else { self }
    }
}
