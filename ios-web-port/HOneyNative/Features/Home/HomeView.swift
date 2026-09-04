// Home (HomePage.tsx + features.css `.home-*`, `.nextlesson*`, `.portal-link`;
// fidelity spec v2 §6, Web 2026-09-03/04): greeting + date with the wordmark
// on the line → the Now/Next card in its 150 pt slot → From school (the
// newest unread notices, at most two) → Related to you (1–2 raw previews,
// the composer prompt inside the zone) → the foot with the School Portal as
// a small link at the right. Zones part with a hairline; no avatars, no
// last-updated, no refresh control — pull to refresh.

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
    @State private var openNotice: SchoolNotice?
    /// The page's own height before it is stretched to the screen, so Home
    /// only scrolls when it has more than a screen of content.
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height <= 700
            // Home does not pull to refresh and does not stretch (Gary
            // 2026-09-04: 让首页无法向上滑动). The shared refresher needs the
            // scroll view to bounce at both ends — iOS has no one-ended bounce
            // — so Home leaves it out: scrolling is off entirely while the
            // page fits the screen, and a page that outgrows it scrolls as an
            // ordinary long page does. Fresh data comes silently on every
            // return to the tab (`.task` below); nothing on screen is ever
            // cleared to make room for a spinner.
            let fits = contentHeight > 0 && contentHeight <= geo.size.height
            ScrollView {
                VStack(alignment: .leading, spacing: HSpace.x4) {
                    if let me = env.me {
                        HStack(alignment: .top, spacing: HSpace.x3) {
                            VStack(alignment: .leading, spacing: HSpace.x1) {
                                Text(L10n.greeting(me.displayName))
                                    .hfont(.greeting)
                                    // `.home-head__hi`: ink, as the Web at
                                    // cebb399 (Gary 2026-09-05: 参照正确的做).
                                    .foregroundStyle(theme.ink)
                                    .accessibilityAddTraits(.isHeader)
                                Text(Formatters.dayTitle(Formatters.todayIsoDate()))
                                    .hfont(.secondary)
                                    .foregroundStyle(theme.ink2)
                            }
                            Spacer(minLength: HSpace.x3)
                            // `.home-head__mark`: the wordmark at 22 px, 4 px
                            // down from the row's top (an SVG prop on the
                            // Web — it does not follow Text size).
                            WordmarkView(height: 22)
                                .padding(.top, 4)
                        }
                        .pageInset()
                        // `.main` on phones: 16 pt (+ the inset) above the head.
                        .padding(.top, HSpace.x4)
                    }

                    if let model {
                        lessonRegion(model, compact: compact)
                            .frame(minHeight: 150, alignment: .top)
                            .pageInset()
                        if !model.homeNotices.isEmpty {
                            noticesRegion(model)
                                .pageInset()
                        }
                        voicesRegion(model, previewCount: compact ? 1 : 2, lineLimit: compact ? 2 : 3)
                            .pageInset()
                    } else {
                        LoadingPlaceholder(lines: 2).pageInset()
                    }

                    // Nothing is pinned to the foot of the page: `.stack.home`
                    // at cebb399 lets the portal zone follow the voices like
                    // every other zone (Gary 2026-09-05, the Web screenshot).
                    // `.home-foot.home-zone`: the portal entry is marginal by design
                    // (Gary 2026-09-03: 很小的边缘非胶囊) — a small link at the right.
                    VStack(alignment: .leading, spacing: 0) {
                        HairlineDivider()
                        HStack {
                            Spacer(minLength: 0)
                            PortalLink(signedIn: env.portal.signedInEntry != nil) { showPortal = true }
                        }
                        .padding(.top, HSpace.x4)
                    }
                    .pageInset()
                }
                .padding(.bottom, HSpace.x4)
                .background(
                    GeometryReader { content in
                        Color.clear
                            .onAppear { contentHeight = content.size.height }
                            .onChange(of: content.size.height) { _, h in contentHeight = h }
                    }
                )
                .frame(minHeight: geo.size.height, alignment: .top)
            }
            .scrollDisabled(fits)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .surfaceBackground()
        .toolbar(.hidden, for: .navigationBar)
        .navigationTitle("Home")
        .task {
            // Runs on every return to the tab: a silent reload behind what
            // is already showing.
            if model == nil { model = HomeViewModel(env: env) }
            await model?.load()
        }
        .fullScreenCover(isPresented: $showPortal) { PortalView() }
        .sheet(item: $openNotice) { notice in
            NoticeSheet(notice: notice, portalOrigin: model?.portalOrigin ?? "") { model?.markRead(notice) }
        }
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

    /// `.home-notices.home-zone`: the label with "All notices" at the right,
    /// then the rows that open a notice in a sheet.
    private func noticesRegion(_ model: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HairlineDivider()
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.t("From school")).sectionLabel()
                Spacer(minLength: HSpace.x3)
                Button(L10n.t("All notices")) { nav.push(.notices) }
                    .buttonStyle(.webLink)
                    .frame(minHeight: 0)
            }
            .padding(.top, HSpace.x4)
            .padding(.bottom, HSpace.x2)
            ForEach(Array(model.homeNotices.enumerated()), id: \.element.id) { index, notice in
                if index > 0 { HairlineDivider() }
                Button { openNotice = notice } label: {
                    // `.home-notices__title` is 15/600 here; the /notices page's
                    // own row keeps the body size.
                    NoticeRow(notice: notice, unread: model.isUnread(notice), titleRole: .secondarySemibold)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// `.home-voices.home-zone`: rule above, 16 pt in, the label, the rows,
    /// the composer prompt. Reserves 132 pt so nothing shifts when it resolves.
    @ViewBuilder
    private func voicesRegion(_ model: HomeViewModel, previewCount: Int, lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HairlineDivider()
            Text(L10n.t("Related to you"))
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
                    ExperiencePreviewRow(exp: exp, mine: model.isMine(exp), name: model.name, lineLimit: lineLimit) {
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
/// chevron centred at the right. Idle, the card wears a light accent wash
/// from its top-left corner; while a lesson runs the base stays plain and
/// the progress wash alone fills it from the left with the scheme's
/// companion colour at 22 %.
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
///
/// Both washes are PAINT, not layout: the idle corner gradient and the
/// running fill are gradients whose stops carry the fraction, so nothing
/// reads geometry a frame late — the fill moves with the card while the
/// page rubber-bands on a pull (Gary 2026-09-04: 填充跟不上回弹).
private struct HeroCard<Content: View>: View {
    @Environment(\.theme) private var theme
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
            .background { ground }
            .overlay(alignment: .trailing) {
                ChevronGlyph().padding(.trailing, HSpace.x4)
            }
            .clipShape(RoundedRectangle(cornerRadius: HRadius.hero, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HRadius.hero, style: .continuous).strokeBorder(theme.line, lineWidth: 1))
            .shadow(color: theme.shadow, radius: 20, y: 14)
            .contentShape(RoundedRectangle(cornerRadius: HRadius.hero, style: .continuous))
    }

    @ViewBuilder
    private var ground: some View {
        if let progress {
            // `.nextlesson__wash`: left-to-right, proportional to elapsed time,
            // a hard stop at the fraction — steps once per tick, never interpolates.
            let stop = min(1, max(0, progress))
            LinearGradient(
                stops: [
                    .init(color: theme.progressWash, location: 0),
                    .init(color: theme.progressWash, location: stop),
                    .init(color: .clear, location: stop),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .background(theme.surfaceSolid)
            .transaction { $0.animation = nil }
        } else {
            // `.nextlesson:not(.nextlesson--live)`: the wash starts in the
            // top-left corner and fades out across the card (Gary 2026-09-03:
            // 从一个角开始, 不要太明显) — 9 % accent → 5 % at 45 % → the surface.
            LinearGradient(
                stops: [
                    .init(color: theme.palette.accent.mixed(with: theme.palette.surfaceSolid, amount: 0.09).color, location: 0),
                    .init(color: theme.palette.accent.mixed(with: theme.palette.surfaceSolid, amount: 0.05).color, location: 0.45),
                    .init(color: theme.surfaceSolid, location: 1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

/// `.home-voices__row`: the words at 15/1.5 (3 lines; 2 on compact), then
/// Yours · course · teacher · day as a caption.
struct ExperiencePreviewRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let exp: PublicExperienceV2
    var mine = false
    let name: NameResolver
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
                let caption = ExperienceDisplay.previewCaption(exp, name: name)
                if mine || !caption.isEmpty {
                    HStack(spacing: 0) {
                        if mine {
                            // Your own words are marked here too (Gary 2026-09-03).
                            Text("\(L10n.t("Yours")) · ").font(ramp.font(.captionBold)).foregroundStyle(theme.accent)
                        }
                        Text(caption).font(ramp.font(.caption)).foregroundStyle(theme.muted).lineLimit(2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, HSpace.x3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// `.composer-prompt`: a field-shaped entry at the foot of the voices — its
/// own colour, apart from the lesson card above: the scheme's COMPANION hue,
/// faint (Gary 2026-09-03; per-scheme since 2026-09-04 — the green belongs to
/// Harbour, every other scheme brings its own pairing): the frame barely
/// tinted, the fill a wash that fades out from left to right, the card shadow.
struct ComposerPromptRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: HSpace.x3) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(theme.palette.companion.mixed(with: theme.palette.muted, amount: 0.7).color)
                Text(L10n.t("Share what a lesson was like…"))
                    .font(ramp.font(.secondary))
                    .foregroundStyle(theme.ink2)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, HSpace.x4)
            .padding(.vertical, HSpace.x3)
            .frame(minHeight: HSize.control)
            .background(
                LinearGradient(
                    stops: [
                        .init(color: theme.palette.companion.mixed(with: theme.palette.cell, amount: 0.07).color, location: 0),
                        .init(color: theme.palette.companion.mixed(with: theme.palette.cell, amount: 0.03).color, location: 0.45),
                        .init(color: theme.cell, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).strokeBorder(theme.palette.companion.mixed(with: theme.palette.line, amount: 0.12).color, lineWidth: 1))
            .cardShadow(theme)
            .contentShape(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("Share an experience"))
    }
}

/// `.portal-link`: no box, no fill, no capsule — the portal's mark, "School
/// Portal" underlined in the accent, and a small note: "Signed in" when the
/// entry is ready (in the installed app it says what it does — it enters the
/// portal signed in, here), else the outward arrow. 44 pt tap zone.
struct PortalLink: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let signedIn: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: HSpace.x2) {
                Image("OASIS")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .clipShape(Circle())
                    .opacity(0.75)
                    .colorInvert(if: theme.isNight)
                    .accessibilityHidden(true)
                Text("School Portal")
                    .font(ramp.font(.caption))
                    .underline(true, pattern: .solid)
                    .foregroundStyle(theme.accent)
                Text(signedIn ? L10n.t("Signed in") : "↗")
                    .font(ramp.font(.caption))
                    .foregroundStyle(theme.muted)
            }
            .padding(.vertical, HSpace.x2)
            .frame(minHeight: HSize.control)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("School Portal, \(signedIn ? L10n.t("Signed in") : L10n.t("Open the official site"))")
    }
}

private extension View {
    @ViewBuilder
    func colorInvert(if condition: Bool) -> some View {
        if condition { self.colorInvert() } else { self }
    }
}
