// The Week overview (WeekView.tsx + features.css `.week*`; fidelity spec v2
// §12.4): a period matrix — Mon–Fri (plus a weekend day only when it has
// lessons, then it scrolls sideways), rows P1–P6 with Lunch/Dinner as
// spanning separators, subject + room per cell, today's column in the
// scheme's tint, the running lesson ink-filled, unplaced lessons listed
// beneath. At accessibility sizes the matrix becomes a day-by-day list.

import SwiftUI
import HOneyCore

struct WeekTimetableView: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @Environment(\.dynamicTypeSize) private var typeSize
    let model: TimetableViewModel
    let onOpenDay: (String) -> Void

    /// A day column in a week that scrolls sideways is exactly as wide as a
    /// day column in a Mon–Fri week on the same phone (Gary 2026-09-04): the
    /// region minus the page inset, the gutter and the five 2 pt gaps, over
    /// five — so a weekend column adds width, it never squeezes the days.
    private func dayColumnWidth(in regionWidth: CGFloat) -> CGFloat {
        floor((regionWidth - 20 - gutterWidth - 5 * 2) / 5)
    }
    private let gutterWidth: CGFloat = 32
    /// The matrix fills the visible height (Gary 2026-09-03: 周课表稍微填满一点
    /// 屏幕): the period rows share what the region leaves below the day
    /// header, clamped so a small phone keeps readable cells and a tall one
    /// does not balloon. Measured on this device, never a per-model guess.
    private static let cellMin: CGFloat = 56
    private static let cellMax: CGFloat = 104
    @State private var cellHeight: CGFloat = 66
    /// Where the day columns sit when they scroll (weekend weeks only): a
    /// week only changes from the edge the student has actually reached.
    @State private var scrollEdges = WeekScrollEdges()
    /// The day columns' visible width, measured — never derived from the
    /// region width, which is what left `atEnd` unreachable on some weeks.
    @State private var daysViewport: CGFloat = 0
    /// True while an armed sideways pull is under the finger on a scrolling
    /// week: the days' own scroll is switched off so they do not rubber-band
    /// on top of the pull.
    @State private var pullLocksScroll = false
    /// Bumped on every committed pull, so the phone taps once as the week turns.
    @State private var weekSteps = 0
    /// The sideways pull to change week (WeekPull, below) is parked: the feel
    /// was not right on the device and the work stops here for now (Gary
    /// 2026-09-04, 太怪了先不启用). The code stays; nothing is attached while
    /// this is false — no gesture, no offset, no badge, no scroll lock.
    private static let weekPullEnabled = false

    var body: some View {
        let matrix = WeekMatrix(monday: model.monday, days: model.weekDays)
        GeometryReader { geo in
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                if let error = model.weekError, model.weekDays == nil {
                    InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await model.load(reload: true) } })).pageInset()
                }
                // The selected week's data or a loading matrix — never another week's.
                if typeSize.isAccessibilitySize {
                    accessibleList(matrix)
                } else {
                    // One pull modifier over both shapes of week, on a real
                    // container: a Group is transparent, so its offset landed
                    // on whichever branch was showing, and a week that arrived
                    // as the other branch was a brand-new view with no
                    // previous offset to animate from — it just appeared
                    // (Gary 2026-09-04, every turn into a 6-day week). The
                    // VStack keeps one identity, so the slide always plays and
                    // the branch swap inside it is silent.
                    VStack(alignment: .leading, spacing: 0) {
                        if matrix.dates.count > 5 {
                            HStack(alignment: .top, spacing: 2) {
                                stickyGutter()
                                ScrollView(.horizontal, showsIndicators: false) {
                                    grid(matrix, fixedColumns: true, showsGutter: false, columnWidth: dayColumnWidth(in: geo.size.width))
                                        .background(
                                            GeometryReader { content in
                                                let frame = content.frame(in: .named(Self.daysScrollSpace))
                                                Color.clear.preference(
                                                    key: WeekScrollEdgeKey.self,
                                                    value: WeekScrollEdges(atStart: frame.minX >= -2, atEnd: frame.maxX <= daysViewport + 2)
                                                )
                                            }
                                        )
                                }
                                .scrollDisabled(pullLocksScroll)
                                .coordinateSpace(name: Self.daysScrollSpace)
                                .background(
                                    GeometryReader { port in
                                        Color.clear
                                            .onAppear { daysViewport = port.size.width }
                                            .onChange(of: port.size.width) { _, w in daysViewport = w }
                                    }
                                )
                                .onPreferenceChange(WeekScrollEdgeKey.self) { scrollEdges = $0 }
                            }
                            .padding(.horizontal, 10)
                            .transition(.identity)
                        } else {
                            grid(matrix, fixedColumns: false, showsGutter: true).padding(.horizontal, 10)
                                .transition(.identity)
                        }
                    }
                    // Same as the Day canvas: the matrix is a fixed grid, so
                    // system Dynamic Type is capped and Text size still scales.
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
                    .weekPull(
                        enabled: Self.weekPullEnabled,
                        canPull: { armed(for: $0, daysScroll: matrix.dates.count > 5) },
                        locksScroll: $pullLocksScroll,
                        onCommit: turnWeek
                    )
                }
                if !matrix.unplaced.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(L10n.t("Outside the school periods")).sectionLabel().padding(.bottom, HSpace.x2)
                        ForEach(Array(matrix.unplaced.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { HairlineDivider() }
                            Button { model.selectedLesson = item.lesson } label: {
                                EntityRow(
                                    title: item.lesson.title,
                                    caption: [Formatters.dayTitle(item.date), Formatters.timeRange(item.lesson.startsAt, item.lesson.endsAt), DisplayNames.roomLabel(item.lesson.roomName)]
                                        .filter { !$0.isEmpty }.joined(separator: " · "),
                                    showsDisclosure: false
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .pageInset()
                }
            }
            .padding(.bottom, HSpace.x4)
        }
        .honeyRefreshable { await model.load(reload: true) }
        .sensoryFeedback(.impact(weight: .light), trigger: weekSteps)
        .onAppear { fit(geo.size.height) }
        .onChange(of: geo.size.height) { _, height in fit(height) }
        }
    }

    /// The day header row, and the break separators, are the two heights the
    /// sticky period column has to mirror, so both are constants here and the
    /// chrome that fills them is pinned to px (Gary 2026-09-04) — the matrix
    /// is a grid, and a grid whose labels grow is a grid that misaligns.
    private static let breakRowHeight: CGFloat = 26
    private var headerRowHeight: CGFloat { HSize.control + HSpace.x1 }

    /// `.week__gutter` in a period row: P-number over the start time, at the
    /// Web's 13/11 px, on one line inside 32 pt.
    private func gutterCell(_ band: TimelineBand) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("P\(band.periodNumber ?? 0)")
                .font(HOneyFont.fixedFont(role: .captionBold))
                .foregroundStyle(theme.accent)
                .lineLimit(1)
            Text(PeriodCatalog.minuteLabel(band.start))
                .font(HOneyFont.fixedFont(role: TypeRole(size: 11, weight: 400, textStyle: .caption2, tracking: 0, lineHeight: 1)))
                .monospacedDigit()
                .foregroundStyle(theme.muted)
                .lineLimit(1)
                .allowsTightening(true)
                .minimumScaleFactor(0.8)
        }
        .padding(.top, HSpace.x2)
        .frame(width: gutterWidth, height: cellHeight, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    /// `.week__table th.week__gutter { position: sticky; left: 0 }`: when a
    /// weekend column makes the matrix wider than the phone, the days scroll
    /// sideways and the period column stays put (Gary 2026-09-04). It is a
    /// sibling of the scroller rather than an overlay, so the two can never
    /// drift: every row height it mirrors is a constant or `cellHeight`.
    private func stickyGutter() -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(width: gutterWidth, height: headerRowHeight)
            ForEach(PeriodCatalog.bands) { band in
                if band.isPeriod {
                    gutterCell(band)
                } else {
                    // The break band runs under the gutter on the Web too.
                    Rectangle()
                        .fill(theme.tint(theme.palette.accent, 0.06))
                        .frame(width: gutterWidth, height: Self.breakRowHeight)
                        .overlay(alignment: .top) { Rectangle().fill(theme.line).frame(height: 1) }
                }
            }
        }
        .background(theme.surface)
        .accessibilityHidden(true)
    }

    private static let daysScrollSpace = "week.days"

    /// A pull towards `direction` (+1 next week) is armed unless the day
    /// columns still have somewhere to scroll that way. Mon–Fri weeks (an
    /// empty weekend is hidden, WeekView.tsx) never scroll, so they are armed
    /// from the first point; a week with a weekend column scrolls its days
    /// first and only arms at the edge, so browsing Saturday never flips the
    /// week by accident.
    private func armed(for direction: Int, daysScroll: Bool) -> Bool {
        guard daysScroll else { return true }
        return direction > 0 ? scrollEdges.atEnd : scrollEdges.atStart
    }

    private func turnWeek(_ direction: Int) {
        weekSteps += 1
        model.step(direction)
    }

    /// (available − day header − break rows − 4 pt rounding margin) / periods.
    private func fit(_ available: CGFloat) {
        let header: CGFloat = HSize.control + HSpace.x1
        let breaks = CGFloat(PeriodCatalog.bands.filter { !$0.isPeriod }.count) * 26
        let periods = CGFloat(max(1, PeriodCatalog.bands.filter(\.isPeriod).count))
        let next = floor((available - header - breaks - HSpace.x4 - 4) / periods)
        let clamped = min(Self.cellMax, max(Self.cellMin, next))
        if clamped != cellHeight { cellHeight = clamped }
    }

    /// `.week__table`: 2 pt column spacing, no row spacing; the gutter stays.
    private func grid(_ matrix: WeekMatrix, fixedColumns: Bool, showsGutter: Bool, columnWidth: CGFloat = 0) -> some View {
        let today = Formatters.todayIsoDate()
        let now = HOneyClock.now().epochMillis
        return Grid(alignment: .topLeading, horizontalSpacing: 2, verticalSpacing: 0) {
            GridRow {
                if showsGutter { Color.clear.frame(width: gutterWidth, height: 1) }
                ForEach(matrix.dates, id: \.self) { date in
                    Button { onOpenDay(date) } label: {
                        VStack(spacing: 1) {
                            Text(Formatters.weekdayShort(date))
                                .font(HOneyFont.fixedFont(role: .microSemibold))
                                .foregroundStyle(date == today ? theme.accent : theme.ink2)
                            Text("\(Formatters.dayNumber(date))")
                                .font(HOneyFont.fixedFont(role: TypeRole(size: 16, weight: 650, textStyle: .body, tracking: 0, lineHeight: 1)))
                                .monospacedDigit()
                                .foregroundStyle(date == today ? theme.accent : theme.ink)
                        }
                        .frame(maxWidth: .infinity, minHeight: HSize.control, maxHeight: HSize.control)
                        .background(date == today ? theme.accentTint : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(Formatters.dayTitle(date))")
                    .padding(.bottom, HSpace.x1)
                    .gridCellUnsizedAxes(fixedColumns ? [] : .horizontal)
                    .frame(width: fixedColumns ? columnWidth : nil)
                }
            }
            ForEach(PeriodCatalog.bands) { band in
                if band.isPeriod {
                    GridRow {
                        if showsGutter { gutterCell(band) }
                        ForEach(matrix.dates, id: \.self) { date in
                            let cell = matrix.cell(date: date, band: band)
                            WeekCell(cell: cell, isToday: date == today, isNow: cell.first.map { WeekMatrix.isNow($0, now: now) } ?? false, loading: model.weekDays == nil && model.loading, height: cellHeight) {
                                if let first = cell.first { model.selectedLesson = first }
                            }
                            .frame(width: fixedColumns ? columnWidth : nil)
                        }
                    }
                } else {
                    GridRow {
                        Text("\(band.breakLabel?.replacingOccurrences(of: " Break", with: "") ?? "") · \(PeriodCatalog.minuteLabel(band.start))–\(PeriodCatalog.minuteLabel(band.end))")
                            .font(HOneyFont.fixedFont(role: .microSemibold))
                            .foregroundStyle(theme.muted)
                            .frame(maxWidth: .infinity, minHeight: Self.breakRowHeight, maxHeight: Self.breakRowHeight, alignment: .center)
                            .background(theme.tint(theme.palette.accent, 0.06))
                            .overlay(alignment: .top) { Rectangle().fill(theme.line).frame(height: 1) }
                            .gridCellColumns(matrix.dates.count + (showsGutter ? 1 : 0))
                    }
                }
            }
        }
    }

    /// A semantically complete alternative when five columns cannot be read.
    private func accessibleList(_ matrix: WeekMatrix) -> some View {
        VStack(alignment: .leading, spacing: HSpace.x4) {
            ForEach(matrix.dates, id: \.self) { date in
                VStack(alignment: .leading, spacing: 0) {
                    Button { onOpenDay(date) } label: {
                        HStack {
                            Text(Formatters.dayTitle(date)).font(ramp.font(.bodySemibold)).foregroundStyle(theme.ink)
                            Spacer()
                            ChevronGlyph()
                        }
                        .frame(minHeight: HSize.control)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    ForEach(PeriodCatalog.periods) { band in
                        let cell = matrix.cell(date: date, band: band)
                        if let first = cell.first {
                            Button { model.selectedLesson = first } label: {
                                LessonRow(lesson: first, leading: "P\(band.periodNumber ?? 0)")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HairlineDivider()
                }
            }
        }
        .pageInset()
    }
}

/// `.week__cell` + `.week__lesson`: a ruled cell, today's column tinted; a
/// lesson is a bordered cell-ground box (subject 13/600, room micro), the
/// running one ink-filled.
struct WeekCell: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let cell: WeekMatrix.Cell
    let isToday: Bool
    let isNow: Bool
    let loading: Bool
    var height: CGFloat = 66
    let tap: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(isToday ? theme.todayColumn : Color.clear)
                .overlay(alignment: .top) { Rectangle().fill(theme.line).frame(height: 1) }
            if let first = cell.first {
                Button(action: tap) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(DisplayNames.compactLessonTitle(first, phone: true))
                            .font(ramp.font(.captionSemibold))
                            .foregroundStyle(isNow ? theme.surface : theme.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if let room = first.roomName, !room.isEmpty {
                            // `.week__room` is meta, not reading: the Web's 12 px
                            // in a 66 pt cell, pinned so it cannot push the
                            // subject out of the block (Gary 2026-09-04).
                            Text(room)
                                .font(HOneyFont.fixedFont(role: .micro))
                                .monospacedDigit()
                                .foregroundStyle(isNow ? theme.surface.opacity(0.8) : theme.muted)
                                .lineLimit(1)
                        }
                        if cell.extraCount > 0 {
                            Text("+\(cell.extraCount)").font(ramp.font(.microBold)).foregroundStyle(isNow ? theme.surface : theme.accent)
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, HSpace.x2)
                    .frame(maxWidth: .infinity, minHeight: height - 4, alignment: .topLeading)
                    .background(isNow ? theme.ink : theme.cell, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(isNow ? theme.ink : theme.line, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
                .accessibilityLabel(label(first))
            } else if loading {
                Capsule().fill(theme.soft).frame(height: 14).padding(.horizontal, 5).padding(.top, HSpace.x2)
            } else {
                Color.clear.accessibilityLabel("\(Formatters.dayTitle(cell.date)), Period \(cell.band.periodNumber ?? 0), free.")
            }
        }
        .frame(maxWidth: .infinity, minHeight: height)
    }

    private func label(_ first: Lesson) -> String {
        [
            "\(Formatters.dayTitle(cell.date)), Period \(cell.band.periodNumber ?? 0)",
            first.title,
            "\(Formatters.time(first.startsAt)) to \(Formatters.time(first.endsAt))",
            first.teacherName,
            DisplayNames.roomLabel(first.roomName),
            cell.extraCount > 0 ? "and \(cell.extraCount) more" : nil,
            isNow ? L10n.t("Now") : nil,
        ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}


/// Where a horizontally scrolling week sits, so the sideways pull only arms at
/// the edge the student has actually reached.
struct WeekScrollEdges: Equatable {
    var atStart = true
    var atEnd = true
}

struct WeekScrollEdgeKey: PreferenceKey {
    static let defaultValue = WeekScrollEdges()
    static func reduce(value: inout WeekScrollEdges, nextValue: () -> WeekScrollEdges) { value = nextValue() }
}

extension View {
    /// Pull the matrix sideways to change week (Gary 2026-09-04, the ChatGPT
    /// "pull past the end" recording). `canPull` says whether a pull in that
    /// direction (+1 next) may arm right now; `onCommit` turns the week.
    @ViewBuilder
    func weekPull(enabled: Bool = true, canPull: @escaping (Int) -> Bool, locksScroll: Binding<Bool>, onCommit: @escaping (Int) -> Void) -> some View {
        if enabled {
            modifier(WeekPull(canPull: canPull, locksScroll: locksScroll, onCommit: onCommit))
        } else {
            self
        }
    }
}

/// The pull, all of it, in one modifier so a drag re-renders only this offset
/// and the badge — never the Grid behind it (that rebuild was the stutter).
///
/// Feel (Gary 2026-09-04): an ordinary sideways movement does nothing at all —
/// the first `deadZone` points of travel are swallowed and the page looks
/// exactly as it does without this gesture. Past that the matrix gives way
/// gently on an exponential curve that never exceeds `maxPull`, the badge
/// fades in from `reveal` and is fully there at `commit`, and the week turns
/// only when the finger lets go past `commit` — or flicks hard enough that it
/// would have. On a turn the new week slides in from the side being pulled
/// towards, so it is unmistakable that the week changed; a short pull settles
/// back with nothing happening. The direction is latched on the first clear
/// movement and the settle is critically damped, so the badge never crosses
/// to the other edge.
private struct WeekPull: ViewModifier {
    @Environment(\.theme) private var theme
    let canPull: (Int) -> Bool
    /// Set for the life of an armed pull on a scrolling week.
    @Binding var locksScroll: Bool
    let onCommit: (Int) -> Void

    /// Finger travel that is swallowed entirely.
    private let deadZone: CGFloat = 48
    /// The pull's asymptote and its curve's scale, in damped points.
    private let maxPull: CGFloat = 88
    private let curve: CGFloat = 110
    /// Damped distances: badge starts, badge complete + week turns.
    private let reveal: CGFloat = 24
    private let commit: CGFloat = 64
    /// Where the incoming week starts, as a fraction of the matrix width.
    private let entry: CGFloat = 0.28

    @State private var swipe: CGFloat = 0
    @State private var direction = 0
    /// Decided once, when the direction latches: whether this pull may act at
    /// all. On a scrolling week it is the edge state at that moment — a drag
    /// that starts mid-scroll stays a scroll for its whole life, even if it
    /// reaches the edge, so the matrix never jumps under a moving finger.
    @State private var armed = false
    @State private var pulling = false
    @State private var incoming = false

    private var progress: CGFloat { min(1, max(0, (abs(swipe) - reveal) / (commit - reveal))) }
    private var forward: Bool { direction >= 0 }

    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        // `.offset` moves only the drawing, so the overlay and the gesture stay
        // on the matrix's own frame: the badge sits in the gap the pull opens.
        content
            .offset(x: swipe)
            .opacity(incoming ? 0.55 : 1)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { width = geo.size.width }
                        .onChange(of: geo.size.width) { _, w in width = w }
                }
            )
            .overlay(alignment: forward ? .trailing : .leading) {
                if direction != 0 { badge }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(drag)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if direction == 0 {
                    guard abs(dx) > abs(dy) else { return }
                    direction = dx < 0 ? 1 : -1
                    armed = canPull(direction)
                    if armed { locksScroll = true }
                }
                guard armed else { return }
                let along = direction > 0 ? max(0, -dx) : max(0, dx)
                pulling = true
                swipe = CGFloat(-direction) * damped(along)
            }
            .onEnded { value in
                let d = direction
                let dx = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let along = d > 0 ? max(0, -dx) : max(0, dx)
                let flung = d > 0 ? max(0, -predicted) : max(0, predicted)
                let committed = d != 0 && armed
                    && (damped(along) >= commit || (damped(along) >= reveal && damped(flung) >= commit))
                locksScroll = false
                armed = false
                withAnimation(.easeOut(duration: 0.14)) { pulling = false }
                if committed {
                    onCommit(d)
                    // The new week arrives from the side pulled towards.
                    var swap = Transaction(); swap.disablesAnimations = true
                    withTransaction(swap) {
                        swipe = CGFloat(d) * width * entry
                        incoming = true
                    }
                    withAnimation(.spring(response: 0.42, dampingFraction: 1)) {
                        swipe = 0
                        incoming = false
                    }
                } else {
                    withAnimation(.spring(response: 0.34, dampingFraction: 1)) { swipe = 0 }
                }
                direction = 0
            }
    }

    /// Zero until the dead zone, then an exponential approach to `maxPull`.
    private func damped(_ along: CGFloat) -> CGFloat {
        let extra = along - deadZone
        guard extra > 0 else { return 0 }
        return maxPull * (1 - exp(-extra / curve))
    }

    private var badge: some View {
        VStack(spacing: 5) {
            Image(systemName: forward ? "chevron.right" : "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.surface)
                .frame(width: 34, height: 34)
                .background(theme.accent, in: Circle())
            Text(L10n.t(forward ? "Next week" : "Previous week"))
                .font(HOneyFont.fixedFont(role: .microSemibold))
                .foregroundStyle(theme.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .scaleEffect(0.82 + 0.18 * progress)
        .opacity(pulling ? Double(progress) : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
