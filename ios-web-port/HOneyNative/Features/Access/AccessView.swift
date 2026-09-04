// Access (fidelity spec v2 §16): the one surface with no Web page, built
// from the current Web grammar — Source Sans, the chosen Background and
// Accent, sentence-case section labels, `.card`, hairline rows, the Web
// button family, the banner family. Layout after what Gary asked for: an
// apply-permit card (Start / End / Reason, +1 badge, quick defaults), the
// permit list with status chips and Choose gate on an openable permit, and
// the school-access dock — Day student / Exit permit — leading to a gate
// picker and a confirmation before anything physical happens. Pull to
// refresh always works; the list also refreshes on appear and foreground.

import SwiftUI
import HOneyCore

struct AccessView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @State private var model: AccessViewModel?
    @State private var editing: PermitField?
    @State private var showAllPermits = false
    @State private var gateRoute: AccessRoute?
    @State private var confirm: GateConfirmation?
    @State private var choosePermit = false
    @State private var quickApplyPrompt = false
    @State private var withdrawing: ExitPermit?
    @State private var showSchoolLogin = false

    private let collapsedPermits = 3

    struct GateConfirmation: Identifiable {
        let route: AccessRoute
        let door: PortalDoor
        var id: String { "\(route.recordId)-\(door.id)" }
    }

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                LoadingPlaceholder(lines: 4).pageInset()
            }
        }
        .surfaceBackground()
        .toolbar(.hidden, for: .navigationBar)
        .navigationTitle("Access")
        .task {
            if model == nil { model = AccessViewModel(env: env) }
            await model?.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model?.refresh(keepBanner: true, force: true) } }
        }
        .onChange(of: env.scope) { _, _ in
            model?.reset()
            Task { await model?.refresh(force: true) }
        }
        .sheet(isPresented: $showSchoolLogin) {
            SchoolLoginSheet(purpose: .save) { Task { await model?.refresh(force: true) } }
        }
    }

    @ViewBuilder
    private func content(_ model: AccessViewModel) -> some View {
        let refreshModel = model
        @Bindable var model = model
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: HSpace.x4) {
                    HStack(alignment: .center, spacing: HSpace.x3) {
                        PageTitle(text: "Access")
                        Button { Task { await model.refresh(keepBanner: true, force: true) } } label: {
                            if model.loading {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.webIcon)
                        .disabled(model.loading)
                        .accessibilityLabel("Refresh Access")
                    }
                    if let banner = model.banner {
                        InlineStatusBanner(text: banner.text, tone: banner.tone, action: ("OK", { model.banner = nil }))
                    }
                    if model.needsSchoolLogin {
                        InlineStatusBanner(
                            text: model.permitsError ?? "Access needs your school login kept on this iPhone.",
                            tone: .warning,
                            action: ("Update school login", { showSchoolLogin = true })
                        )
                    } else if let doorsError = model.doorsError, model.banner == nil {
                        InlineStatusBanner(text: doorsError, tone: .warning, action: (L10n.t("Try again"), { Task { await model.refresh() } }))
                    }
                    applyCard(model)
                    permitsSection(model)
                    accessDock(model)
                }
                .frame(minHeight: geo.size.height, alignment: .top)
                .pageInset()
                .padding(.top, HSpace.x2)
                .padding(.bottom, HSpace.x4)
            }
            .honeyRefreshable { await refreshModel.refresh(keepBanner: true, force: true) }
        }
        .sheet(item: $editing) { field in
            PermitDraftEditor(field: field, draft: $model.draft)
        }
        .sheet(item: $gateRoute) { route in
            GatePickerSheet(route: route, doors: model.doors) { door in
                gateRoute = nil
                confirm = GateConfirmation(route: route, door: door)
            }
        }
        .sheet(item: $confirm) { request in
            ConfirmSheet(
                title: "Open \(request.door.displayName)?",
                message: "This opens a physical gate. Only do this when you are there.",
                confirmLabel: "Open \(request.door.displayName)",
                onCancel: { confirm = nil },
                onConfirm: {
                    confirm = nil
                    Task { await model.openGate(route: request.route, door: request.door) }
                }
            )
        }
        .sheet(isPresented: $choosePermit) {
            WebSheet(title: "Choose permit", onClose: { choosePermit = false }) {
                Text("Select the permit to use for this gate opening.")
                    .hfont(.body)
                    .foregroundStyle(theme.muted)
                    .padding(.bottom, HSpace.x2)
                VStack(spacing: 0) {
                    ForEach(Array(model.openable.enumerated()), id: \.element.id) { index, permit in
                        if index > 0 { HairlineDivider() }
                        Button {
                            choosePermit = false
                            beginGateFlow(model, route: .permit(recordId: permit.recordId))
                        } label: {
                            EntityRow(title: permit.displayReason, caption: permit.displayWhen)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $quickApplyPrompt) {
            ConfirmSheet(
                title: "No active permit",
                message: "No approved, unused exit permit covers right now. Submit the start, end and reason shown in the draft first?",
                confirmLabel: "Apply with this draft",
                onCancel: { quickApplyPrompt = false },
                onConfirm: { quickApplyPrompt = false; Task { await model.applyPermit() } }
            )
        }
        .sheet(item: $withdrawing) { permit in
            ConfirmSheet(
                title: "Withdraw this permit request?",
                message: "The request is deleted on the school portal. You can apply again any time.",
                confirmLabel: "Withdraw request",
                danger: true,
                onCancel: { withdrawing = nil },
                onConfirm: { withdrawing = nil; Task { await model.deletePermit(permit) } }
            )
        }
    }

    // MARK: Apply permit (`.card`)

    private func applyCard(_ model: AccessViewModel) -> some View {
        VStack(alignment: .leading, spacing: HSpace.x3) {
            HStack(alignment: .firstTextBaseline) {
                Text("Apply for a permit").font(ramp.font(.bodySemibold)).foregroundStyle(theme.ink)
                Spacer()
                Text(Formatters.shortDate(model.draft.start)).font(ramp.font(.caption)).foregroundStyle(theme.muted)
            }
            HStack(spacing: HSpace.x2) {
                PermitFieldButton(title: "Start", value: Formatters.time(model.draft.start.epochMillis)) { editing = .start }
                PermitFieldButton(title: "End", value: Formatters.time(model.draft.end.epochMillis), badge: model.draft.crossesMidnight ? "+1" : nil) { editing = .end }
            }
            PermitFieldButton(title: "Reason", value: model.draft.cleanedReason) { editing = .reason }
            Button(model.working ? "Applying…" : "Apply for permit") { Task { await model.applyPermit() } }
                .buttonStyle(.webBlockPrimary)
                .disabled(model.working || model.needsSchoolLogin)
        }
        .webCard()
    }

    // MARK: Permits

    private func permitsSection(_ model: AccessViewModel) -> some View {
        let permits = model.listed
        let visible = showAllPermits ? permits : Array(permits.prefix(collapsedPermits))
        return VStack(alignment: .leading, spacing: HSpace.x2) {
            if permits.count > collapsedPermits, showAllPermits {
                Button {
                    togglePermitExpansion()
                } label: {
                    HStack(spacing: HSpace.x2) {
                        Text("Permits").sectionLabel()
                        Spacer()
                        HStack(spacing: HSpace.x1) {
                            Text("Show fewer")
                            Image(systemName: "chevron.up")
                        }
                        .font(ramp.font(.captionSemibold))
                        .foregroundStyle(theme.accent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Permits, show fewer")
                .accessibilityValue("Expanded")
            } else {
                Text("Permits").sectionLabel()
            }
            if model.loading, permits.isEmpty {
                LoadingPlaceholder(lines: 2)
            } else {
                if let stale = model.staleMessage, !model.needsSchoolLogin {
                    InlineStatusBanner(text: stale + (permits.isEmpty ? "" : " The list below may be out of date and cannot open a gate until it is refreshed."), tone: .warning, action: (L10n.t("Try again"), { Task { await model.refresh(keepBanner: true, force: true) } }))
                }
                if visible.isEmpty {
                    Text(model.permitsUsable ? "No permits." : "Permits unavailable.").hfont(.body).foregroundStyle(theme.muted)
                        .padding(.vertical, HSpace.x2)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { index, permit in
                            VStack(spacing: 0) {
                                if index > 0 { HairlineDivider() }
                                PermitRow(permit: permit, actionable: model.permitsUsable && !model.working) {
                                    beginGateFlow(model, route: .permit(recordId: permit.recordId))
                                } withdraw: {
                                    withdrawing = permit
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                if permits.count > collapsedPermits, !showAllPermits {
                    Button {
                        togglePermitExpansion()
                    } label: {
                        HStack(spacing: HSpace.x1) {
                            Text("Show all \(permits.count) permits")
                            Image(systemName: "chevron.down")
                        }
                        .font(ramp.font(.captionSemibold))
                        .foregroundStyle(theme.accent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show all \(permits.count) permits")
                    .accessibilityValue("Collapsed")
                }
            }
        }
    }

    private func togglePermitExpansion() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            showAllPermits.toggle()
        }
    }

    // MARK: School access dock

    private func accessDock(_ model: AccessViewModel) -> some View {
        VStack(alignment: .leading, spacing: HSpace.x2) {
            Text("School access").sectionLabel()
            HStack(spacing: HSpace.x3) {
                AccessActionCard(title: "Day student", symbol: "figure.walk.departure") {
                    beginGateFlow(model, route: .commuter)
                }
                AccessActionCard(title: "Exit permit", symbol: "doc.text") {
                    beginPermitSelection(model)
                }
            }
        }
        .padding(.top, HSpace.x2)
    }

    private func beginGateFlow(_ model: AccessViewModel, route: AccessRoute) {
        guard model.commuterRouteAvailable else {
            model.banner = (.warning, model.doorsError ?? "Gate names are unavailable. Refresh Access and try again.")
            return
        }
        gateRoute = route
    }

    private func beginPermitSelection(_ model: AccessViewModel) {
        guard model.permitsUsable else {
            model.banner = (.warning, model.staleMessage ?? "Permits are not available yet. Refresh Access and try again.")
            return
        }
        let usable = model.openable
        if usable.isEmpty {
            quickApplyPrompt = true
        } else if usable.count == 1, let only = usable.first {
            beginGateFlow(model, route: .permit(recordId: only.recordId))
        } else {
            choosePermit = true
        }
    }
}

// MARK: - Pieces

enum PermitField: String, Identifiable {
    case start, end, reason
    var id: String { rawValue }
    var title: String {
        switch self {
        case .start: return "Start time"
        case .end: return "End time"
        case .reason: return "Reason"
        }
    }
}

/// A draft field as a soft-ground control: label in micro, the value, a chevron.
struct PermitFieldButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let title: String
    let value: String
    var badge: String?
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: HSpace.x2) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(ramp.font(.microSemibold)).foregroundStyle(theme.muted)
                    Text(value).font(ramp.font(.secondaryMedium)).monospacedDigit().foregroundStyle(theme.ink).lineLimit(1)
                }
                Spacer(minLength: 4)
                if let badge {
                    Text(badge).font(ramp.font(.microBold)).foregroundStyle(theme.accent)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(theme.accentTint, in: Capsule())
                }
                ChevronGlyph(size: 14)
            }
            .padding(.horizontal, HSpace.x3)
            .frame(maxWidth: .infinity, minHeight: HSize.control, alignment: .leading)
            .background(theme.soft, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(value)\(badge != nil ? ", next day" : "")")
    }
}

struct PermitDraftEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    let field: PermitField
    @Binding var draft: PermitDraft
    @State private var start: Date
    @State private var end: Date
    @State private var reason: String

    init(field: PermitField, draft: Binding<PermitDraft>) {
        self.field = field
        _draft = draft
        _start = State(initialValue: draft.wrappedValue.start)
        _end = State(initialValue: draft.wrappedValue.end)
        _reason = State(initialValue: draft.wrappedValue.reason)
    }

    var body: some View {
        WebSheet(title: field.title, onClose: { dismiss() }) {
            switch field {
            case .start:
                DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
                Text("The date stays on today; the end moves if it would fall before the start.").hfont(.caption).foregroundStyle(theme.muted)
            case .end:
                DatePicker("End", selection: $end, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
                Text("An end earlier than the start counts as the next day (+1).").hfont(.caption).foregroundStyle(theme.muted)
            case .reason:
                FieldLabel(text: "Reason")
                TextField("", text: $reason)
                    .textFieldStyle(.web)
                    .submitLabel(.done)
                    .onSubmit { save() }
                Text("Left empty, the reason is out.").hfont(.caption).foregroundStyle(theme.muted).padding(.top, HSpace.x2)
            }
            SheetActions {
                Button(L10n.t("Done")) { save() }.buttonStyle(.webBlockPrimary)
            }
        }
        .presentationDetents([field == .reason ? .medium : .medium])
    }

    private func save() {
        switch field {
        case .start: draft.setStart(start)
        case .end: draft.setEnd(end)
        case .reason: draft.reason = reason
        }
        dismiss()
    }
}

struct PermitRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let permit: ExitPermit
    let actionable: Bool
    let chooseGate: () -> Void
    let withdraw: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let openable = actionable && permit.isOpenable(now: context.date)
            let color = tone(permit.tone(now: context.date))
            HStack(alignment: .center, spacing: HSpace.x3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(permit.displayReason).font(ramp.font(.bodySemibold)).foregroundStyle(theme.ink)
                    Text(permit.displayWhen).font(ramp.font(.caption)).monospacedDigit().foregroundStyle(theme.muted)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: HSpace.x1) {
                    StatusChip(text: permit.displayStatus, ink: color, ground: color.opacity(0.1))
                    if openable {
                        Button("Choose gate", action: chooseGate)
                            .buttonStyle(.webSmallPrimary)
                            .accessibilityHint("Choose a gate to open with this permit")
                    }
                }
            }
            .padding(.vertical, HSpace.x3)
            .frame(minHeight: HSize.row)
            .contextMenu {
                if permit.status == .pending {
                    Button("Withdraw request", systemImage: "xmark.circle", role: .destructive, action: withdraw)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func tone(_ t: ExitPermit.Tone) -> Color {
        switch t {
        case .ok: return theme.ok
        case .warning: return theme.accent
        case .danger: return theme.danger
        case .muted: return theme.muted
        }
    }
}

/// A dock card (`.card` at the control radius): an accent-tinted glyph
/// tile, the title, one line of state.
struct AccessActionCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let title: String
    let symbol: String
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: HSpace.x3) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(theme.accent)
                    .frame(width: 34, height: 34)
                    .background(theme.accentTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title)
                    .font(ramp.font(.secondarySemibold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(HSpace.x3)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(theme.card, in: RoundedRectangle(cornerRadius: HRadius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HRadius.control, style: .continuous).strokeBorder(theme.line, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: HRadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Every gate the portal names, as rows (rule: all options visible).
struct GatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    let route: AccessRoute
    let doors: [PortalDoor]
    let choose: (PortalDoor) -> Void

    var body: some View {
        WebSheet(title: "Choose gate", onClose: { dismiss() }) {
            Text(route == .commuter ? "Day student access" : "Exit permit access").sectionLabel().padding(.bottom, HSpace.x1)
            VStack(spacing: 0) {
                ForEach(Array(doors.enumerated()), id: \.element.id) { index, door in
                    if index > 0 { HairlineDivider() }
                    Button { choose(door) } label: {
                        EntityRow(title: door.displayName)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("You will confirm before the gate opens.").hfont(.caption).foregroundStyle(theme.muted).padding(.top, HSpace.x3)
        }
        .presentationDetents([.medium, .large])
    }
}
