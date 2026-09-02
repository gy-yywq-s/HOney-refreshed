// Home (spec §10): brand bar → greeting/date → the separate Now/Next card
// → 1–3 raw previews from your classes with the composer prompt inside the
// voices zone → the School Portal row, with no School heading. No avatars,
// no last-updated, no refresh toolbar — pull to refresh.

import SwiftUI
import HOneyCore

struct HomeView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @State private var model: HomeViewModel?
    @State private var showPortal = false

    /// 2 previews on ordinary/tall phones, 3 on genuinely tall ones, 1 on compact.
    private var previewCount: Int {
        let h = UIScreen.main.bounds.height
        if h >= 900 { return 3 }
        if h >= 700 { return 2 }
        return 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HOneyBrandHeader()
                if let me = env.me {
                    VStack(alignment: .leading, spacing: HSpace.x1) {
                        Text(L10n.greeting(me.displayName))
                            .font(HType.greeting)
                            .foregroundStyle(Color.honeyInk)
                        Text(Formatters.dayTitle(Formatters.todayIsoDate()))
                            .font(HType.secondary)
                            .foregroundStyle(Color.honeySecondary)
                    }
                    .pageInset()
                    .padding(.top, HSpace.x5)
                    .padding(.bottom, HSpace.x5)
                }

                if let model {
                    lessonRegion(model)
                        .pageInset()
                    voicesRegion(model)
                        .padding(.top, HSpace.x6)
                } else {
                    LoadingPlaceholder(lines: 2).pageInset()
                }

                HairlineDivider().padding(.top, HSpace.x5)
                PortalRow { showPortal = true }
                    .pageInset()
                    .padding(.vertical, HSpace.x2)
            }
            .padding(.bottom, HSpace.x7)
        }
        .background(Color.honeyCanvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await model?.load(reload: true) }
        .task {
            if model == nil { model = HomeViewModel(env: env) }
            await model?.load()
        }
        .fullScreenCover(isPresented: $showPortal) { PortalView() }
    }

    @ViewBuilder
    private func lessonRegion(_ model: HomeViewModel) -> some View {
        if model.lessonLoading, model.nextLesson == nil {
            NowNextLessonCard.placeholder
        } else if let error = model.lessonError, model.nextLesson == nil {
            InlineStatusBanner(text: error, tone: .danger, action: ("Try again", { Task { await model.load(reload: true) } }))
        } else if let next = model.nextLesson?.nextLesson {
            NowNextLessonCard(next: next) {
                nav.timetableIntent = TimetableIntent(date: Formatters.toIsoDate(Date(epochMillis: next.lesson.startsAt)), view: .day)
                nav.go(.timetable)
            }
        } else {
            NowNextLessonCard.empty { nav.go(.timetable) }
        }
    }

    @ViewBuilder
    private func voicesRegion(_ model: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HairlineDivider()
            HStack {
                Text("From your classes").eyebrow()
                Spacer()
                Button(L10n.t("See all")) { nav.go(.experiences) }
                    .font(HType.meta)
            }
            .pageInset()
            .padding(.top, HSpace.x4)
            .padding(.bottom, HSpace.x2)

            if model.previewsLoading, model.previews.isEmpty {
                LoadingPlaceholder(lines: 2).pageInset()
            } else if model.previews.isEmpty {
                Text(L10n.t("When someone shares an experience connected to your classes, it will appear here."))
                    .font(HType.secondary)
                    .foregroundStyle(Color.honeySecondary)
                    .pageInset()
                    .padding(.vertical, HSpace.x2)
            } else {
                ForEach(Array(model.previews.prefix(previewCount).enumerated()), id: \.element.id) { index, exp in
                    if index > 0 { HairlineDivider().pageInset() }
                    ExperiencePreviewRow(exp: exp, lineLimit: previewCount >= 3 ? 2 : 3) {
                        nav.go(.experiences)
                    }
                    .pageInset()
                }
            }

            ComposerPromptRow { nav.push(.compose(nil)) }
                .pageInset()
                .padding(.top, HSpace.x3)
        }
    }
}

/// Centred wordmark in a 48 pt band over a full-width hairline (spec §10.2).
struct HOneyBrandHeader: View {
    var body: some View {
        VStack(spacing: 0) {
            WordmarkView(height: 30)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            Rectangle().fill(Color.honeyFrame).frame(height: 1.5)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// The separate Now/Next card (spec §10.4): one temporal header line,
/// subject largest, exact time first, teacher · room after; a clipped
/// elapsed-time fill behind the content for a running lesson; the whole
/// card is one target with a quiet chevron.
struct NowNextLessonCard: View {
    let next: NextLesson
    let open: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Cadence: the clock text and fill move every 30 s, nothing else re-renders.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let p = HomeLessonPresentation(next, now: context.date)
            Button(action: open) {
                VStack(alignment: .leading, spacing: HSpace.x3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(p.stateLabel).eyebrow()
                        Spacer()
                        Text(p.when)
                            .font(HType.micro.weight(.semibold).monospacedDigit())
                            .textCase(.uppercase)
                            .kerning(0.4)
                            .foregroundStyle(p.soon ? Color.honeyAccent : Color.honeySecondary)
                    }
                    HStack(alignment: .center) {
                        Text(p.subject)
                            .font(HType.lessonSubject)
                            .foregroundStyle(Color.honeyInk)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: HSpace.x2)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.honeyTertiary)
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: HSpace.x2) { details(p) }
                        VStack(alignment: .leading, spacing: 2) { details(p) }
                    }
                }
                .padding(HSpace.x4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    ZStack(alignment: .leading) {
                        Color.honeyCell
                        if let progress = p.progress {
                            GeometryReader { geo in
                                Color.honeyAccent.opacity(0.14)
                                    .frame(width: geo.size.width * progress)
                                    .animation(reduceMotion ? nil : .linear(duration: 0.6), value: progress)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: HRadius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HRadius.card, style: .continuous).stroke(Color.honeyFrame, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(p.accessibilityLabel)
        }
    }

    @ViewBuilder
    private func details(_ p: HomeLessonPresentation) -> some View {
        Text(p.timeRange)
            .font(HType.secondary.monospacedDigit())
            .foregroundStyle(Color.honeyInk)
            .fixedSize()
        let who = [p.teacher, p.room].compactMap { $0 }.joined(separator: " · ")
        if !who.isEmpty {
            Text(who)
                .font(HType.secondary)
                .foregroundStyle(Color.honeySecondary)
                .lineLimit(2)
        }
    }

    /// Geometry-preserving placeholder while the first load runs.
    static var placeholder: some View {
        VStack(alignment: .leading, spacing: HSpace.x3) {
            Text("Next lesson").eyebrow()
            LoadingPlaceholder(lines: 2)
        }
        .padding(HSpace.x4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.honeyCell, in: RoundedRectangle(cornerRadius: HRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HRadius.card, style: .continuous).stroke(Color.honeyFrame, lineWidth: 1.5))
    }

    /// Visibly shorter than the lesson card: no empty hero shell.
    static func empty(open: @escaping () -> Void) -> some View {
        Button(action: open) {
            HStack {
                VStack(alignment: .leading, spacing: HSpace.x1) {
                    Text(L10n.t("Nothing coming up")).eyebrow()
                    Text(L10n.t("No upcoming lessons in your timetable."))
                        .font(HType.body)
                        .foregroundStyle(Color.honeyInk)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.honeyTertiary)
            }
            .padding(HSpace.x4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.honeyCell, in: RoundedRectangle(cornerRadius: HRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HRadius.card, style: .continuous).stroke(Color.honeyFrame, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

/// One raw preview: the words first, then a quiet course · teacher · day.
struct ExperiencePreviewRow: View {
    let exp: PublicExperience
    var lineLimit = 3
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: HSpace.x1) {
                Text(exp.body ?? "")
                    .font(HType.reading)
                    .foregroundStyle(Color.honeyInk)
                    .lineLimit(lineLimit)
                    .multilineTextAlignment(.leading)
                let caption = ExperienceDisplay.previewCaption(exp)
                if !caption.isEmpty {
                    Text(caption).font(HType.meta).foregroundStyle(Color.honeySecondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, HSpace.x3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The field-shaped composer prompt inside the voices zone (spec §10.6).
struct ComposerPromptRow: View {
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: HSpace.x3) {
                Image(systemName: "pencil")
                    .font(.subheadline)
                    .foregroundStyle(Color.honeySecondary)
                Text(L10n.t("Share what a lesson was like…"))
                    .font(HType.body)
                    .foregroundStyle(Color.honeySecondary)
                Spacer()
            }
            .padding(.horizontal, HSpace.x4)
            .frame(minHeight: 46)
            .background(Color.honeyCell, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).stroke(Color.honeyLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("Share an experience"))
    }
}

/// School Portal as a direct row — no School heading (spec §10.7).
struct PortalRow: View {
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: HSpace.x3) {
                Image("OASIS")
                    .resizable()
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("School Portal").font(HType.body).foregroundStyle(Color.honeyInk)
                    Text(L10n.t("Official site")).font(HType.meta).foregroundStyle(Color.honeySecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.honeyTertiary)
            }
            .padding(.vertical, HSpace.x3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("School Portal, \(L10n.t("Open the official site"))")
    }
}
