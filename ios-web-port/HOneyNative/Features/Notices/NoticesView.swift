// What the school published on the portal (NoticesPage.tsx + NoticeSheet.tsx
// + features.css `.notice-*`; Gary 2026-09-03). The school's words are shown
// verbatim, in the language the school wrote them; only HOney's own chrome
// switches language. A notice is read in a sheet that opens at reading height
// and can be pulled up to full height; "Open as a page" still leads to the
// full screen. New/read is a fact of THIS device and is never sent anywhere.

import SwiftUI
import HOneyCore

@MainActor
@Observable
final class NoticesViewModel {
    private let env: AppEnvironment
    private(set) var notices: [SchoolNotice] = []
    private(set) var portalOrigin = ""
    private(set) var loading = true
    private(set) var error: String?
    private(set) var readVersion = 0

    init(env: AppEnvironment) { self.env = env }

    func load() async {
        do {
            let response = try await env.api.notices(limit: 50)
            notices = response.notices
            portalOrigin = response.portalOrigin
            error = nil
        } catch {
            if notices.isEmpty { self.error = APIErrorCopy.describe(error) }
        }
        loading = false
    }

    func isUnread(_ notice: SchoolNotice) -> Bool {
        _ = readVersion
        return !env.prefs.readNotices().contains(notice.id)
    }

    var unreadCount: Int { notices.filter { isUnread($0) }.count }

    func markRead(_ notice: SchoolNotice) {
        env.prefs.markNoticesRead([notice.id])
        readVersion += 1
    }

    func markAllRead() {
        env.prefs.markNoticesRead(notices.map(\.id))
        readVersion += 1
    }
}

struct NoticesView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @State private var model: NoticesViewModel?
    @State private var open: SchoolNotice?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                // `.page-head--tools`: the title with the finishing action beside it.
                HStack(alignment: .center, spacing: HSpace.x3) {
                    PageTitle(text: L10n.t("From school"))
                    if let model, model.unreadCount > 0 {
                        Button(L10n.t("Mark all read")) { model.markAllRead() }
                            .buttonStyle(.webPillOk)
                    }
                }
                if let model {
                    if model.loading, model.notices.isEmpty {
                        LoadingPlaceholder(lines: 5)
                    } else if let error = model.error, model.notices.isEmpty {
                        InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await model.load() } }))
                    } else if model.notices.isEmpty {
                        Text(L10n.t("The school has not published anything yet."))
                            .hfont(.body)
                            .foregroundStyle(theme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(HSpace.x6)
                            .webCard()
                    } else {
                        // `.notice-list`: ruled rows, each the whole tap zone.
                        VStack(spacing: 0) {
                            ForEach(Array(model.notices.enumerated()), id: \.element.id) { index, notice in
                                if index > 0 { HairlineDivider() }
                                Button { open = notice } label: {
                                    NoticeRow(notice: notice, unread: model.isUnread(notice), excerpt: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    LoadingPlaceholder(lines: 5)
                }
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
        .honeyRefreshable { await model?.load() }
        .webScreen(title: L10n.t("From school"))
        .task {
            if model == nil { model = NoticesViewModel(env: env) }
            await model?.load()
        }
        .sheet(item: $open) { notice in
            NoticeSheet(notice: notice, portalOrigin: model?.portalOrigin ?? "") { model?.markRead(notice) }
        }
    }
}

/// `.notice-row__link`: dot (unread) + title, the relative day, a one-line
/// excerpt of the school's text; chevron at the right; 56 pt minimum.
struct NoticeRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let notice: SchoolNotice
    let unread: Bool
    var excerpt = false

    var body: some View {
        HStack(alignment: .center, spacing: HSpace.x4) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: HSpace.x2) {
                    if unread {
                        // Unread, on THIS device: the school is never told what was opened.
                        Circle().fill(theme.accent).frame(width: 7, height: 7)
                            .accessibilityLabel(L10n.t("New"))
                    }
                    Text(notice.title)
                        .font(ramp.font(.bodySemibold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(excerpt ? 2 : 1)
                        .multilineTextAlignment(.leading)
                }
                Text(Formatters.relativeDay(notice.postedAt))
                    .font(ramp.font(.caption))
                    .foregroundStyle(theme.muted)
                    .lineLimit(1)
                if excerpt {
                    Text(notice.body.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).prefix(90))
                        .font(ramp.font(.caption))
                        .foregroundStyle(theme.muted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ChevronGlyph()
        }
        .padding(.vertical, HSpace.x3)
        .frame(minHeight: HSize.row)
        .contentShape(Rectangle())
    }
}

/// The school writes its attachments into the text as `[name.pdf](</path>)`
/// (live capture 2026-09-03). Where the school wrote a file link it becomes a
/// real link to the portal; the words around it are untouched.
enum NoticeBody {
    private static let fileLink = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\(\s*<?([^)>]+?)>?\s*\)"#)

    static func href(_ target: String, origin: String) -> URL? {
        let path = target.trimmingCharacters(in: .whitespaces)
        if path.lowercased().hasPrefix("http://") || path.lowercased().hasPrefix("https://") {
            return URL(string: path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path)
        }
        if path.hasPrefix("/"), !origin.isEmpty {
            var base = origin
            while base.hasSuffix("/") { base.removeLast() }
            return URL(string: base + (path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path))
        }
        return nil
    }

    /// The body as attributed text: plain, whitespace kept, file links live.
    static func attributed(_ body: String, origin: String) -> AttributedString {
        var out = AttributedString()
        let ns = body as NSString
        var last = 0
        for m in fileLink.matches(in: body, options: [], range: NSRange(location: 0, length: ns.length)) {
            if m.range.location > last {
                out += AttributedString(ns.substring(with: NSRange(location: last, length: m.range.location - last)))
            }
            let name = ns.substring(with: m.range(at: 1))
            let target = ns.substring(with: m.range(at: 2))
            if let url = href(target, origin: origin) {
                var link = AttributedString(name)
                link.link = url
                link.font = .body.weight(.semibold)
                out += link
            } else {
                out += AttributedString(ns.substring(with: m.range))
            }
            last = m.range.location + m.range.length
        }
        if last < ns.length { out += AttributedString(ns.substring(from: last)) }
        return out
    }
}

/// One notice in a sheet: opens at reading height, a pull up takes it
/// full-height (the native detents ARE the Web's two heights). The handle and
/// the title stay put while the text scrolls under them.
struct NoticeSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @Environment(Navigator.self) private var nav
    @Environment(\.dismiss) private var dismiss
    let notice: SchoolNotice
    let portalOrigin: String
    let onOpened: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // `.modal__sticky`: handle + title, opaque, ruled beneath.
            VStack(alignment: .leading, spacing: 0) {
                Capsule().fill(theme.line).frame(width: 36, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, HSpace.x3)
                    .padding(.bottom, HSpace.x3)
                HStack(alignment: .top, spacing: HSpace.x3) {
                    Text(notice.title)
                        .hfont(.modalTitle)
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                    Button { dismiss() } label: {
                        Text("×")
                            .hfont(.title)
                            .foregroundStyle(theme.muted)
                            .frame(width: HSize.control, height: HSize.control)
                            .overlay(Circle().strokeBorder(theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                .padding(.bottom, HSpace.x2)
            }
            .padding(.horizontal, HSpace.x4)
            .background(theme.surfaceSolid)
            .overlay(alignment: .bottom) { HairlineDivider() }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    NoticeDocument(notice: notice, portalOrigin: portalOrigin)
                    // Where the school's words end and HOney's note begins.
                    HStack(spacing: HSpace.x1) {
                        Text(L10n.t("Published by the school on the portal."))
                        Button(L10n.t("Open as a page")) {
                            dismiss()
                            nav.push(.notice(notice.id))
                        }
                        .buttonStyle(WebLinkStyle(role: .caption))
                        .frame(minHeight: 0)
                    }
                    .font(ramp.font(.caption))
                    .foregroundStyle(theme.muted)
                    .padding(.top, HSpace.x4)
                    .padding(.top, HSpace.x6)
                    .overlay(alignment: .top) { HairlineDivider().padding(.top, HSpace.x6) }
                }
                .padding(.horizontal, HSpace.x4)
                .padding(.top, HSpace.x3)
                .padding(.bottom, HSpace.x6)
            }
        }
        .background(theme.surfaceSolid.ignoresSafeArea())
        .presentationDetents([.fraction(0.58), .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(HRadius.modal)
        .presentationBackground(theme.surfaceSolid)
        .onAppear(perform: onOpened)
    }
}

/// The date line (apart from the headline), then the body as written.
private struct NoticeDocument: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let notice: SchoolNotice
    let portalOrigin: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(metaLine)
                .font(ramp.font(.caption))
                .foregroundStyle(theme.muted)
                .padding(.top, HSpace.x3)
            Text(NoticeBody.attributed(notice.body, origin: portalOrigin))
                .font(ramp.font(.body))
                .lineSpacing(ramp.lineSpacing(.reading))
                .foregroundStyle(theme.ink)
                .tint(theme.accent)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .padding(.top, HSpace.x4)
        }
    }

    private var metaLine: String {
        var s = "\(Formatters.relativeDay(notice.postedAt)) · \(Formatters.time(notice.postedAt))"
        if notice.updatedAt > notice.postedAt { s += " · \(L10n.t("Edited")) \(Formatters.relativeDay(notice.updatedAt))" }
        return s
    }
}

/// /notices/:id — the same notice as a full page (`.doc.notice-doc`).
struct NoticeDocView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let noticeId: String
    @State private var model: NoticesViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let model, !model.loading || !model.notices.isEmpty {
                    if let notice = model.notices.first(where: { $0.id == noticeId }) {
                        Text(notice.title)
                            .hfont(.pageTitle)
                            .foregroundStyle(theme.ink)
                            .accessibilityAddTraits(.isHeader)
                        NoticeDocument(notice: notice, portalOrigin: model.portalOrigin)
                        Text(L10n.t("Published by the school on the portal."))
                            .font(ramp.font(.caption))
                            .foregroundStyle(theme.muted)
                            .padding(.top, HSpace.x4)
                            .padding(.top, HSpace.x6)
                            .overlay(alignment: .top) { HairlineDivider().padding(.top, HSpace.x6) }
                    } else {
                        PageTitle(text: L10n.t("Notice"))
                        Text(L10n.t("This notice is no longer in the school's list."))
                            .hfont(.body)
                            .foregroundStyle(theme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(HSpace.x6)
                            .webCard()
                            .padding(.top, HSpace.x4)
                        Button(L10n.t("All notices")) { nav.pop() }
                            .buttonStyle(.webPrimary)
                            .padding(.top, HSpace.x4)
                    }
                } else {
                    LoadingPlaceholder(lines: 6)
                }
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
        .webScreen(title: L10n.t("Notice"))
        .task {
            if model == nil { model = NoticesViewModel(env: env) }
            await model?.load()
            if let notice = model?.notices.first(where: { $0.id == noticeId }) { model?.markRead(notice) }
        }
    }
}
