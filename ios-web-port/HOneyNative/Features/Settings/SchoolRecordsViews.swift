// Settings › At school (SchoolRecordsPages.tsx + features.css `.cardbalance`,
// `.daypick`, `.topup__amounts`; Gary 2026-09-03/04): the student's own
// school records — campus card, weekend stay, disciplinary record, lesson
// feedback. Read live, stored nowhere, and every action the school offers is
// offered here too: top up, apply, withdraw, send feedback. Bilingual chrome;
// the school's wording is never translated — and never explained at length:
// one short line at most.

import SwiftUI
import SafariServices
import WebKit
import HOneyCore

// MARK: - Shared

private enum SchoolCopy {
    static func reconnect() -> String { L10n.t("HOney needs the school connection for this.") }
    static func unreachable() -> String { L10n.t("The school could not be reached just now.") }
    static func yuan(_ v: Double) -> String { String(format: "¥%.2f", v) }

    static func failure(_ res: SchoolActionResponse) -> String? {
        switch res {
        case .ok: return nil
        case .refused(let reason): return reason
        case .portalReconnectRequired: return L10n.t("The school connection needs renewing.")
        case .unavailable: return L10n.t("The school could not be reached.")
        }
    }

    /// "Fri" / "周五" for a school day string, in the reader's language.
    static func weekday(_ iso: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: L10n.isChinese ? "zh_CN" : "en_GB")
        f.dateFormat = "EEE"
        return f.string(from: Formatters.parseIsoDate(iso))
    }

    /// "12 Sep" / "9月12日".
    static func day(_ iso: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: L10n.isChinese ? "zh_CN" : "en_GB")
        f.setLocalizedDateFormatFromTemplate("d MMM")
        return f.string(from: Formatters.parseIsoDate(iso))
    }
}

/// One line for the two states that are not "here it is".
private struct StateNote: View {
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    let status: SchoolReadStatus
    let empty: String

    var body: some View {
        switch status {
        case .portalReconnectRequired:
            InlineStatusBanner(text: SchoolCopy.reconnect(), tone: .warning, action: (L10n.t("School connection"), { nav.push(.settingsConnection) }))
        case .unavailable:
            emptyCard(SchoolCopy.unreachable())
        case .ok:
            emptyCard(empty)
        }
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text)
            .hfont(.body)
            .foregroundStyle(theme.muted)
            .frame(maxWidth: .infinity)
            .padding(HSpace.x6)
            .webCard()
    }
}

/// `.text-4` "Read live." — the one line these screens are allowed.
private struct ReadLiveLine: View {
    @Environment(\.theme) private var theme
    var body: some View {
        Text(L10n.t("Read live.")).hfont(.caption).foregroundStyle(theme.muted)
    }
}

/// `.row`: a title, a sub, a value at the right.
private struct ValueRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let title: String
    let sub: String
    let value: String
    var valueNote: String?

    var body: some View {
        HStack(alignment: .center, spacing: HSpace.x4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(ramp.font(.bodySemibold)).foregroundStyle(theme.ink)
                Text(sub).font(ramp.font(.caption)).foregroundStyle(theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text(value).font(ramp.font(.secondarySemibold)).monospacedDigit().foregroundStyle(theme.ink)
                if let valueNote { Text(valueNote).font(ramp.font(.caption)).monospacedDigit().foregroundStyle(theme.muted) }
            }
        }
        .padding(.vertical, HSpace.x3)
        .frame(minHeight: HSize.row)
    }
}

// MARK: - Campus card

struct CampusCardView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @State private var data: CardResponse?
    @State private var loading = true
    @State private var error: String?
    @State private var topUp = false
    @State private var showPortal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                PageTitle(text: L10n.t("Campus card"))
                if loading, data == nil {
                    LoadingPlaceholder(lines: 4)
                } else if let error, data == nil {
                    InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await load() } }))
                } else if let data, data.status == .ok, let card = data.card {
                    balance(card)
                    RowList(label: L10n.t("Spending")) {
                        if data.purchases.isEmpty {
                            Text(L10n.t("Nothing on this card yet.")).hfont(.caption).foregroundStyle(theme.muted).padding(.vertical, HSpace.x2)
                        } else {
                            ForEach(data.purchases) { p in
                                ValueRow(title: p.place, sub: "\(Formatters.shortDate(p.at)) · \(Formatters.time(p.at))", value: "−\(SchoolCopy.yuan(p.amount))", valueNote: SchoolCopy.yuan(p.balanceAfter))
                            }
                        }
                    }
                    if !data.topUps.isEmpty {
                        RowList(label: L10n.t("Top-ups")) {
                            ForEach(data.topUps) { r in
                                ValueRow(title: SchoolCopy.yuan(r.amount), sub: "\(Formatters.shortDate(r.at)) · \(Formatters.time(r.at))", value: r.state)
                            }
                        }
                    }
                    ReadLiveLine()
                } else if let data {
                    StateNote(status: data.status, empty: L10n.t("No card is registered to you."))
                }
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
        .honeyRefreshable { await load() }
        .webScreen(title: L10n.t("Campus card"))
        .task { await load() }
        .sheet(isPresented: $topUp) {
            TopUpSheet(onClose: { topUp = false }) {
                topUp = false
                Task { await load() }
            }
        }
        .fullScreenCover(isPresented: $showPortal) { PortalView() }
    }

    /// `.card--hero.cardbalance`: the balance set like the Home hero's figure.
    private func balance(_ card: CampusCard) -> some View {
        VStack(alignment: .leading, spacing: HSpace.x1) {
            Text(L10n.t("Balance")).sectionLabel()
            Text(SchoolCopy.yuan(card.balance))
                .font(ramp.font(TypeRole(size: 34, weight: 650, textStyle: .largeTitle, tracking: -0.03, lineHeight: 1.05)))
                .monospacedDigit()
                .foregroundStyle(theme.ink)
            Text("\(L10n.t("Card")) \(card.cardNo) · \(card.usable ? L10n.t("in use") : L10n.t("not in use"))")
                .hfont(.body)
                .foregroundStyle(theme.muted)
            Text("\(L10n.t("General")) \(SchoolCopy.yuan(card.general)) · \(L10n.t("Subsidy")) \(SchoolCopy.yuan(card.subsidy))")
                .hfont(.caption)
                .foregroundStyle(theme.muted)
            HStack(spacing: HSpace.x2) {
                Button(L10n.t("Top up")) { topUp = true }.buttonStyle(.webPrimary)
                Button(L10n.t("In the portal")) { showPortal = true }.buttonStyle(.webGhost)
            }
            .padding(.top, HSpace.x3)
        }
        .webCard(hero: true)
    }

    private func load() async {
        do {
            data = try await env.api.schoolCard()
            error = nil
        } catch {
            if data == nil { self.error = APIErrorCopy.describe(error) }
        }
        loading = false
    }
}

/// Top up: HOney asks the school to open an order and then hands the student
/// to the school's payment page (Alipay). No money moves in HOney, and an
/// order nobody pays simply stays unpaid — so this asks for an amount, not
/// for a confirmation ritual.
struct TopUpSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    let onClose: () -> Void
    let onPaid: () -> Void
    @State private var amount = cardTopUpAmounts[0]
    @State private var busy = false
    @State private var error: String?
    @State private var pay: PaymentPage?

    var body: some View {
        WebSheet(title: L10n.t("Top up the card"), onClose: onClose) {
            if pay != nil {
                Text(L10n.t("The payment page is open.")).hfont(.body).foregroundStyle(theme.ink)
                SheetActions {
                    Button(L10n.t("Done"), action: onPaid).buttonStyle(.webBlockPrimary)
                }
            } else {
                Text(L10n.t("Opens an Alipay link.")).hfont(.caption).foregroundStyle(theme.muted)
                // Every amount the school offers, all of them visible.
                FlowLayout(spacing: HSpace.x2, rowSpacing: HSpace.x2) {
                    ForEach(cardTopUpAmounts, id: \.self) { v in
                        Button("¥\(v)") { amount = v }
                            .buttonStyle(WebButtonStyle(kind: amount == v ? .pillOk : .ghost, small: true))
                            .accessibilityAddTraits(amount == v ? [.isSelected] : [])
                    }
                }
                .padding(.vertical, HSpace.x3)
                if let error {
                    InlineStatusBanner(text: error, tone: .danger)
                }
                SheetActions {
                    Button(busy ? L10n.t("Checking…") : "\(L10n.t("Continue to pay")) ¥\(amount)") { go() }
                        .buttonStyle(.webBlockPrimary)
                        .disabled(busy)
                    Button(L10n.t("Cancel"), action: onClose).buttonStyle(.webBlockGhost).disabled(busy)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .fullScreenCover(item: $pay) { page in
            PaymentPageView(page: page) { pay = nil }
        }
    }

    private func go() {
        busy = true
        error = nil
        Task {
            do {
                switch try await env.api.schoolCardTopUp(amount: amount) {
                case .ok(let payUrl, let formHtml, let message):
                    if let payUrl, let url = URL(string: payUrl) {
                        pay = PaymentPage(url: url, formHtml: nil)
                    } else if let formHtml, !formHtml.isEmpty {
                        // A payment form is the other shape gateways use: it has to be posted.
                        pay = PaymentPage(url: nil, formHtml: formHtml)
                    } else {
                        error = message.isEmpty ? L10n.t("The school opened the order but did not say where to pay. Open the school portal and finish it there.") : message
                    }
                case .refused(let reason): error = reason
                case .portalReconnectRequired: error = SchoolCopy.reconnect()
                case .unavailable: error = SchoolCopy.unreachable()
                }
            } catch {
                self.error = L10n.t("Could not reach HOney. Try again.")
            }
            busy = false
        }
    }
}

struct PaymentPage: Identifiable {
    var id: String { url?.absoluteString ?? "form" }
    let url: URL?
    let formHtml: String?
}

/// The school's payment page: a URL opens in Safari's own view (Alipay's
/// app links work from there); a form is posted from a WebView.
private struct PaymentPageView: View {
    @Environment(\.theme) private var theme
    let page: PaymentPage
    let close: () -> Void

    var body: some View {
        if let url = page.url {
            SafariView(url: url, close: close).ignoresSafeArea()
        } else {
            NavigationStack {
                FormPostView(html: page.formHtml ?? "")
                    .ignoresSafeArea(edges: .bottom)
                    .toolbar { ToolbarItem(placement: .topBarLeading) { Button(L10n.t("Done"), action: close) } }
            }
        }
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    let close: () -> Void

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(close: close) }

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let close: () -> Void
        init(close: @escaping () -> Void) { self.close = close }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) { close() }
    }
}

private struct FormPostView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView()
        web.loadHTMLString("<!doctype html><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><body>\(html)<script>document.forms[0] && document.forms[0].submit()</script></body>", baseURL: nil)
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Weekend stay

struct WeekendStayView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @State private var data: WeekendResponse?
    @State private var loading = true
    @State private var error: String?
    @State private var picked: [String] = []
    @State private var busy = false
    @State private var note: (tone: BannerTone, text: String)?
    @State private var withdrawing: WeekendStay?
    @State private var showPortal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                PageTitle(text: L10n.t("Weekend stay"))
                if let note { InlineStatusBanner(text: note.text, tone: note.tone) }
                if loading, data == nil {
                    LoadingPlaceholder(lines: 4)
                } else if let error, data == nil {
                    InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await load() } }))
                } else if let data, data.status == .ok {
                    let booked = Set(data.stays.map(\.date))
                    let open = data.selectableDays.filter { !booked.contains($0) }
                    if !open.isEmpty { dayPick(open) }
                    RowList(label: L10n.t("On record")) {
                        if data.stays.isEmpty {
                            Text(L10n.t("Nothing booked.")).hfont(.caption).foregroundStyle(theme.muted).padding(.vertical, HSpace.x2)
                        } else {
                            ForEach(data.stays) { s in
                                ControlRow(title: s.label.isEmpty ? s.date : s.label, sub: [s.campus, s.mentor].filter { !$0.isEmpty }.joined(separator: " · ")) {
                                    Button(L10n.t("Withdraw")) { withdrawing = s }.buttonStyle(.webSmallGhost).disabled(busy)
                                }
                            }
                        }
                    }
                    ReadLiveLine()
                } else if let data {
                    StateNote(status: data.status, empty: L10n.t("Nothing booked."))
                }
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
        .honeyRefreshable { await load() }
        .webScreen(title: L10n.t("Weekend stay"))
        .task { await load() }
        .sheet(item: $withdrawing) { stay in
            ConfirmSheet(title: L10n.t("Withdraw this weekend?"), message: stay.label.isEmpty ? stay.date : stay.label, confirmLabel: L10n.t("Withdraw"), danger: true, busy: busy, onCancel: { withdrawing = nil }) {
                Task { await withdraw(stay) }
            }
        }
        .fullScreenCover(isPresented: $showPortal) { PortalView() }
    }

    /// `.card.daypick`: every open day, each one saying which day it is; a
    /// tight grid, not a loose row (Gary 2026-09-04); "In the portal" is a
    /// corner link, not a button.
    private func dayPick(_ open: [String]) -> some View {
        VStack(alignment: .leading, spacing: HSpace.x2) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.t("Open days")).sectionLabel()
                Spacer(minLength: HSpace.x3)
                Button(L10n.t("In the portal")) { showPortal = true }
                    .buttonStyle(.webLink)
                    .frame(minHeight: 0)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: HSpace.x2)], spacing: HSpace.x2) {
                ForEach(open, id: \.self) { d in
                    let on = picked.contains(d)
                    Button {
                        if on { picked.removeAll { $0 == d } } else { picked.append(d) }
                    } label: {
                        VStack(spacing: 2) {
                            Text(SchoolCopy.weekday(d))
                                .font(ramp.font(.microBold))
                                .tracking(0.6)
                                .foregroundStyle(on ? theme.ok : theme.muted)
                            Text(SchoolCopy.day(d))
                                .font(ramp.font(.secondarySemibold))
                                .foregroundStyle(on ? theme.ok : theme.ink)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .padding(.horizontal, HSpace.x1)
                        .padding(.vertical, HSpace.x2)
                        .background(on ? theme.palette.ok.mixed(with: theme.palette.surfaceSolid, amount: 0.08).color : theme.surfaceSolid, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).strokeBorder(on ? theme.palette.ok.mixed(with: theme.palette.line, amount: 0.55).color : theme.line, lineWidth: 1))
                        .fieldShadow(theme)
                        .contentShape(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(SchoolCopy.weekday(d)) \(SchoolCopy.day(d))")
                    .accessibilityAddTraits(on ? [.isSelected] : [])
                }
            }
            Button(busy ? L10n.t("Saving…") : (picked.isEmpty ? L10n.t("Apply") : "\(L10n.t("Apply")) · \(picked.count)")) { Task { await apply() } }
                .buttonStyle(.webPrimary)
                .disabled(busy || picked.isEmpty)
                .padding(.top, HSpace.x2)
        }
        .webCard()
    }

    private func load() async {
        do {
            data = try await env.api.schoolWeekend()
            error = nil
        } catch {
            if data == nil { self.error = APIErrorCopy.describe(error) }
        }
        loading = false
    }

    private func apply() async {
        guard !picked.isEmpty, !busy else { return }
        busy = true
        note = nil
        do {
            let res = try await env.api.schoolWeekendApply(dates: picked)
            if let failure = SchoolCopy.failure(res) {
                note = (.danger, failure)
            } else {
                note = (.success, L10n.t("Applied."))
                picked = []
                await load()
            }
        } catch {
            note = (.danger, APIErrorCopy.describe(error))
        }
        busy = false
    }

    private func withdraw(_ stay: WeekendStay) async {
        busy = true
        note = nil
        do {
            let res = try await env.api.schoolWeekendWithdraw(recordId: stay.id)
            if let failure = SchoolCopy.failure(res) {
                note = (.danger, failure)
            } else {
                note = (.success, L10n.t("Withdrawn."))
                await load()
            }
        } catch {
            note = (.danger, APIErrorCopy.describe(error))
        }
        busy = false
        withdrawing = nil
    }
}

// MARK: - School record

struct SchoolRecordView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @State private var data: WarningsResponse?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                PageTitle(text: L10n.t("School record"))
                if loading, data == nil {
                    LoadingPlaceholder(lines: 4)
                } else if let error, data == nil {
                    InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await load() } }))
                } else if let data, data.status == .ok {
                    if data.warnings.isEmpty {
                        StateNote(status: .ok, empty: L10n.t("Nothing on record."))
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(data.warnings) { w in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(w.kind).font(ramp.font(.bodySemibold)).foregroundStyle(theme.ink)
                                    Text(w.rule).font(ramp.font(.caption)).foregroundStyle(theme.muted)
                                    if !w.reason.isEmpty {
                                        Text("\(L10n.t("Reason")): \(w.reason)").font(ramp.font(.caption)).foregroundStyle(theme.muted)
                                    }
                                    Text([w.on, w.by].filter { !$0.isEmpty }.joined(separator: " · ")).font(ramp.font(.caption)).foregroundStyle(theme.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, HSpace.x3)
                            }
                        }
                    }
                } else if let data {
                    StateNote(status: data.status, empty: L10n.t("Nothing on record."))
                }
                ReadLiveLine()
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
        .honeyRefreshable { await load() }
        .webScreen(title: L10n.t("School record"))
        .task { await load() }
    }

    private func load() async {
        do {
            data = try await env.api.schoolWarnings()
            error = nil
        } catch {
            if data == nil { self.error = APIErrorCopy.describe(error) }
        }
        loading = false
    }
}

// MARK: - Lesson feedback (the school's own "My Notification" work)

struct LessonFeedbackView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @State private var data: FeedbackResponse?
    @State private var loading = true
    @State private var error: String?
    @State private var open: LessonFeedbackItem?
    @State private var note: (tone: BannerTone, text: String)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                PageTitle(text: L10n.t("Lesson feedback"))
                if let note { InlineStatusBanner(text: note.text, tone: note.tone) }
                if loading, data == nil {
                    LoadingPlaceholder(lines: 4)
                } else if let error, data == nil {
                    InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await load() } }))
                } else if let data, data.status == .ok {
                    if data.pending.isEmpty {
                        StateNote(status: .ok, empty: L10n.t("Nothing waiting."))
                    } else {
                        VStack(spacing: 0) {
                            ForEach(data.pending) { item in
                                Button { open = item } label: {
                                    SettingsRow(title: item.topic, sub: "\(item.teacher) · \(Formatters.shortDate(item.at)) · \(Formatters.time(item.at))")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else if let data {
                    StateNote(status: data.status, empty: L10n.t("Nothing waiting."))
                }
                ReadLiveLine()
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
        .honeyRefreshable { await load() }
        .webScreen(title: L10n.t("Lesson feedback"))
        .task { await load() }
        .sheet(item: $open) { item in
            FeedbackSheet(item: item, onClose: { open = nil }) { ok, text in
                note = (ok ? .success : .danger, text)
                open = nil
                if ok { Task { await load() } }
            }
        }
    }

    private func load() async {
        do {
            data = try await env.api.schoolFeedback()
            error = nil
        } catch {
            if data == nil { self.error = APIErrorCopy.describe(error) }
        }
        loading = false
    }
}

/// The school's own form: a rating, its four issue flags (verbatim), a note.
private struct FeedbackSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let item: LessonFeedbackItem
    let onClose: () -> Void
    let onDone: (Bool, String) -> Void

    @State private var rating = 0
    @State private var comment = ""
    @State private var wasLate = false
    @State private var usedMobile = false
    @State private var unprepared = false
    @State private var didNotUnderstand = false
    @State private var busy = false
    @State private var error: String?

    private var issues: [(label: String, on: Binding<Bool>)] {
        [
            ("Was late", $wasLate),
            ("Used mobile for non-academic purposes", $usedMobile),
            ("Was unprepared for class", $unprepared),
            ("I did not understand the teaching", $didNotUnderstand),
        ]
    }

    var body: some View {
        WebSheet(title: item.topic, onClose: onClose) {
            Text("\(item.teacher) · \(Formatters.shortDate(item.at))").hfont(.caption).foregroundStyle(theme.muted)
            VStack(alignment: .leading, spacing: HSpace.x2) {
                FieldLabel(text: L10n.t("Rating"))
                HStack(spacing: HSpace.x2) {
                    ForEach(1...5, id: \.self) { n in
                        Button("\(n)") { rating = n }
                            .buttonStyle(WebButtonStyle(kind: rating == n ? .pillOk : .ghost, small: true))
                            .accessibilityAddTraits(rating == n ? [.isSelected] : [])
                    }
                }
            }
            .padding(.top, HSpace.x4)
            VStack(alignment: .leading, spacing: HSpace.x2) {
                FieldLabel(text: L10n.t("Issues (if applicable)"))
                ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                    ChoiceOption(label: issue.label, on: issue.on.wrappedValue) { issue.on.wrappedValue.toggle() }
                }
            }
            .padding(.top, HSpace.x4)
            VStack(alignment: .leading, spacing: HSpace.x2) {
                FieldLabel(text: L10n.t("What could be improved?"))
                TextEditor(text: $comment)
                    .font(ramp.font(.body))
                    .foregroundStyle(theme.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 96)
                    .padding(HSpace.x2)
                    .background(theme.surfaceSolid, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).strokeBorder(theme.line, lineWidth: 1))
                    .fieldShadow(theme)
                    .accessibilityLabel(L10n.t("What could be improved?"))
            }
            .padding(.top, HSpace.x4)
            if let error {
                InlineStatusBanner(text: error, tone: .danger).padding(.top, HSpace.x3)
            }
            SheetActions {
                Button(busy ? L10n.t("Saving…") : L10n.t("Send")) { send() }.buttonStyle(.webBlockPrimary).disabled(busy)
                Button(L10n.t("Cancel"), action: onClose).buttonStyle(.webBlockGhost).disabled(busy)
            }
        }
        .presentationDetents([.large])
    }

    private func send() {
        guard rating >= 1 else {
            error = L10n.t("Choose a rating.")
            return
        }
        busy = true
        error = nil
        Task {
            do {
                let res = try await env.api.schoolSubmitFeedback(FeedbackSubmission(
                    lessonId: item.lessonId, rating: rating, comment: comment,
                    wasLate: wasLate, usedMobile: usedMobile, unprepared: unprepared, didNotUnderstand: didNotUnderstand
                ))
                if let failure = SchoolCopy.failure(res) {
                    error = failure
                } else {
                    onDone(true, L10n.t("Sent."))
                }
            } catch {
                self.error = APIErrorCopy.describe(error)
            }
            busy = false
        }
    }
}

/// `.choice-option`: a full-width choice on the solid surface with the field
/// lift; the chosen one takes the accent's border and tint and a tick.
struct ChoiceOption: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let label: String
    var note: String?
    let on: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: HSpace.x3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(ramp.font(.bodySemibold)).foregroundStyle(theme.ink).multilineTextAlignment(.leading)
                    if let note { Text(note).font(ramp.font(.caption)).foregroundStyle(theme.muted) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if on {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, HSpace.x3)
            .padding(.vertical, HSpace.x2)
            .frame(minHeight: 52)
            .background(on ? theme.palette.accent.mixed(with: theme.palette.surfaceSolid, amount: 0.07).color : theme.surfaceSolid, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).strokeBorder(on ? theme.palette.accent.mixed(with: theme.palette.line, amount: 0.55).color : theme.line, lineWidth: 1))
            .fieldShadow(theme)
            .contentShape(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }
}
