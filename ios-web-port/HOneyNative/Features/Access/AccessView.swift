// Access. Layout after what Gary asked for: an apply-permit card (Start /
// End / Reason, +1 badge, quick defaults), the permit list with status
// chips and Choose gate on an openable permit, the status area, and the
// school-access dock — Day student / Exit permit — leading to a gate
// picker and a confirmation before anything physical happens. Pull to
// refresh always works; the list also refreshes on appear and foreground.

import SwiftUI
import HOneyCore

struct AccessView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: AccessViewModel?
    @State private var editing: PermitField?
    @State private var showAllPermits = false
    @State private var gateRoute: AccessRoute?
    @State private var confirm: (route: AccessRoute, door: PortalDoor)?
    @State private var choosePermit = false
    @State private var quickApplyPrompt = false
    @State private var withdrawing: ExitPermit?
    @State private var showSchoolLogin = false

    private let collapsedPermits = 3

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                LoadingPlaceholder(lines: 4).pageInset()
            }
        }
        .background(Color.honeyCanvas.ignoresSafeArea())
        .navigationTitle("Access")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await model?.refresh() } } label: {
                    if model?.loading == true { ProgressView().controlSize(.small) } else { Image(systemName: "arrow.clockwise") }
                }
                .disabled(model?.loading == true)
                .accessibilityLabel("Refresh Access")
            }
        }
        .task {
            if model == nil { model = AccessViewModel(env: env) }
            await model?.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model?.refresh(keepBanner: true) } }
        }
        .onChange(of: env.scope) { _, _ in
            model?.reset()
            Task { await model?.refresh() }
        }
        .sheet(isPresented: $showSchoolLogin) {
            SchoolLoginSheet(purpose: .save) { Task { await model?.refresh() } }
        }
    }

    @ViewBuilder
    private func content(_ model: AccessViewModel) -> some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
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
                permitsCard(model)
                accessDock(model)
            }
            .pageInset()
            .padding(.vertical, HSpace.x2)
            .padding(.bottom, HSpace.x7)
        }
        .refreshable { await model.refresh(keepBanner: true) }
        .sheet(item: $editing) { field in
            PermitDraftEditor(field: field, draft: $model.draft)
        }
        .sheet(item: $gateRoute) { route in
            GatePickerSheet(route: route, doors: model.doors) { door in
                gateRoute = nil
                confirm = (route, door)
            }
        }
        .confirmationDialog(
            "Open \(confirm?.door.displayName ?? "this gate")?",
            isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
            titleVisibility: .visible
        ) {
            Button("Open \(confirm?.door.displayName ?? "gate")") {
                if let request = confirm { Task { await model.openGate(route: request.route, door: request.door) } }
                confirm = nil
            }
            Button(L10n.t("Cancel"), role: .cancel) { confirm = nil }
        } message: {
            Text("This opens a physical gate. Only do this when you are there.")
        }
        .confirmationDialog("Choose permit", isPresented: $choosePermit, titleVisibility: .visible) {
            ForEach(model.openable) { permit in
                Button("\(permit.displayReason) · \(permit.displayWhen)") { beginGateFlow(model, route: .permit(recordId: permit.recordId)) }
            }
            Button(L10n.t("Cancel"), role: .cancel) {}
        } message: {
            Text("Select the permit to use for this gate opening.")
        }
        .confirmationDialog("No active permit", isPresented: $quickApplyPrompt, titleVisibility: .visible) {
            Button("Apply with this draft") { Task { await model.applyPermit() } }
            Button(L10n.t("Cancel"), role: .cancel) {}
        } message: {
            Text("No approved, unused exit permit covers right now. Submit the start, end and reason shown in the draft first?")
        }
        .confirmationDialog("Withdraw this permit request?", isPresented: Binding(get: { withdrawing != nil }, set: { if !$0 { withdrawing = nil } }), titleVisibility: .visible) {
            Button("Withdraw request", role: .destructive) {
                if let permit = withdrawing { Task { await model.deletePermit(permit) } }
                withdrawing = nil
            }
            Button(L10n.t("Cancel"), role: .cancel) { withdrawing = nil }
        }
    }

    // MARK: Apply permit

    private func applyCard(_ model: AccessViewModel) -> some View {
        VStack(alignment: .leading, spacing: HSpace.x3) {
            HStack(alignment: .firstTextBaseline) {
                Text("Apply for a permit").font(HType.body.weight(.semibold)).foregroundStyle(Color.honeyInk)
                Spacer()
                Text(Formatters.shortDate(model.draft.start)).font(HType.meta).foregroundStyle(Color.honeySecondary)
            }
            HStack(spacing: HSpace.x2) {
                PermitFieldButton(title: "Start", value: Formatters.time(model.draft.start.epochMillis)) { editing = .start }
                PermitFieldButton(title: "End", value: Formatters.time(model.draft.end.epochMillis), badge: model.draft.crossesMidnight ? "+1" : nil) { editing = .end }
            }
            PermitFieldButton(title: "Reason", value: model.draft.cleanedReason) { editing = .reason }
            Button {
                Task { await model.applyPermit() }
            } label: {
                Label(model.working ? "Applying…" : "Apply for permit", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.working || model.needsSchoolLogin)
        }
        .padding(HSpace.x4)
        .background(Color.honeyCell, in: RoundedRectangle(cornerRadius: HRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HRadius.card, style: .continuous).stroke(Color.honeyLine, lineWidth: 1))
    }

    // MARK: Permits

    private func permitsCard(_ model: AccessViewModel) -> some View {
        let permits = model.listed
        let visible = showAllPermits ? permits : Array(permits.prefix(collapsedPermits))
        return VStack(alignment: .leading, spacing: HSpace.x2) {
            Text("Permits").font(HType.body.weight(.semibold)).foregroundStyle(Color.honeyInk)
            if model.loading, permits.isEmpty {
                LoadingPlaceholder(lines: 2)
            } else {
                if let stale = model.staleMessage, !model.needsSchoolLogin {
                    InlineStatusBanner(text: stale + (permits.isEmpty ? "" : " The list below may be out of date and cannot open a gate until it is refreshed."), tone: .warning, action: (L10n.t("Try again"), { Task { await model.refresh(keepBanner: true) } }))
                }
                if visible.isEmpty {
                    Text(model.permitsUsable ? "No permits." : "Permits unavailable.").font(HType.secondary).foregroundStyle(Color.honeySecondary)
                        .padding(.vertical, HSpace.x2)
                } else {
                    ForEach(visible) { permit in
                        PermitRow(permit: permit, actionable: model.permitsUsable && !model.working) {
                            beginGateFlow(model, route: .permit(recordId: permit.recordId))
                        } withdraw: {
                            withdrawing = permit
                        }
                        HairlineDivider()
                    }
                }
                if permits.count > collapsedPermits {
                    Button(showAllPermits ? "Show fewer" : "Show all \(permits.count) permits") { withAnimation { showAllPermits.toggle() } }
                        .font(HType.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
    }

    // MARK: School access dock

    private func accessDock(_ model: AccessViewModel) -> some View {
        VStack(alignment: .leading, spacing: HSpace.x2) {
            HStack(alignment: .firstTextBaseline, spacing: HSpace.x2) {
                Text("School access").font(HType.body.weight(.semibold)).foregroundStyle(Color.honeyInk)
                Text("Sent directly to the school").font(HType.micro).foregroundStyle(Color.honeySecondary)
            }
            HStack(spacing: HSpace.x3) {
                AccessActionCard(title: "Day student", subtitle: "Open without an exit permit", symbol: "figure.walk.departure") {
                    beginGateFlow(model, route: .commuter)
                }
                AccessActionCard(title: "Exit permit", subtitle: permitSubtitle(model), symbol: "doc.text") {
                    beginPermitSelection(model)
                }
            }
        }
        .padding(.top, HSpace.x2)
    }

    private func permitSubtitle(_ model: AccessViewModel) -> String {
        if model.loading { return "Checking permits…" }
        guard model.permitsUsable else { return model.permits.isEmpty ? "Permits unavailable" : "Refresh to use a permit" }
        let n = model.openable.count
        return n == 0 ? "No permit usable right now" : n == 1 ? "Use the approved permit" : "Choose one of \(n) permits"
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

struct PermitFieldButton: View {
    let title: String
    let value: String
    var badge: String?
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: HSpace.x2) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(HType.micro.weight(.semibold)).foregroundStyle(Color.honeySecondary)
                    Text(value).font(HType.secondary.weight(.medium).monospacedDigit()).foregroundStyle(Color.honeyInk).lineLimit(1)
                }
                Spacer(minLength: 4)
                if let badge {
                    Text(badge).font(HType.micro.weight(.bold)).foregroundStyle(Color.honeyAccent)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.honeyAccentTint, in: Capsule())
                }
                Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(Color.honeyTertiary)
            }
            .padding(.horizontal, HSpace.x3)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(Color.honeySoft, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(value)\(badge != nil ? ", next day" : "")")
    }
}

struct PermitDraftEditor: View {
    @Environment(\.dismiss) private var dismiss
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
        NavigationStack {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                switch field {
                case .start:
                    DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
                    Text("The date stays on today; the end moves if it would fall before the start.").font(HType.meta).foregroundStyle(Color.honeySecondary)
                case .end:
                    DatePicker("End", selection: $end, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
                    Text("An end earlier than the start counts as the next day (+1).").font(HType.meta).foregroundStyle(Color.honeySecondary)
                case .reason:
                    TextField("Reason", text: $reason)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit { save() }
                    Text("Left empty, the reason is 出门.").font(HType.meta).foregroundStyle(Color.honeySecondary)
                }
                Spacer()
            }
            .pageInset()
            .padding(.top, HSpace.x4)
            .background(Color.honeyCanvas.ignoresSafeArea())
            .navigationTitle(field.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.t("Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(L10n.t("Done")) { save() } }
            }
        }
        .presentationDetents([field == .reason ? .fraction(0.3) : .medium])
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
    let permit: ExitPermit
    let actionable: Bool
    let chooseGate: () -> Void
    let withdraw: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let openable = actionable && permit.isOpenable(now: context.date)
            HStack(alignment: .center, spacing: HSpace.x3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(permit.displayReason).font(HType.body).foregroundStyle(Color.honeyInk)
                    Text(permit.displayWhen).font(HType.meta.monospacedDigit()).foregroundStyle(Color.honeySecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: HSpace.x1) {
                    Text(permit.displayStatus)
                        .font(HType.micro.weight(.semibold))
                        .foregroundStyle(tone(permit.tone(now: context.date)))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(tone(permit.tone(now: context.date)).opacity(0.14), in: Capsule())
                    if openable {
                        Button(action: chooseGate) {
                            Label("Choose gate", systemImage: "lock.open")
                                .font(HType.micro.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .accessibilityHint("Choose a gate to open with this permit")
                    }
                }
            }
            .padding(.vertical, HSpace.x2)
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
        case .ok: return Color.honeySuccess
        case .warning: return Color.honeyWarning
        case .danger: return Color.honeyDanger
        case .muted: return Color.honeyTertiary
        }
    }
}

struct AccessActionCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: HSpace.x3) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.honeyAccent)
                    .frame(width: 34, height: 34)
                    .background(Color.honeyAccentTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(HType.secondary.weight(.semibold)).foregroundStyle(Color.honeyInk).lineLimit(1).minimumScaleFactor(0.85)
                    Text(subtitle).font(HType.micro).foregroundStyle(Color.honeySecondary).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(HSpace.x3)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
            .background(Color.honeyCell, in: RoundedRectangle(cornerRadius: HRadius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HRadius.control, style: .continuous).stroke(Color.honeyLine, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: HRadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Every gate the portal names, as rows (rule: all options visible).
struct GatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let route: AccessRoute
    let doors: [PortalDoor]
    let choose: (PortalDoor) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(doors) { door in
                        Button { choose(door) } label: {
                            EntityRow(title: door.displayName)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(route == .commuter ? "Day student access" : "Exit permit access").eyebrow()
                } footer: {
                    Text("You will confirm before the gate opens.")
                }
            }
            .navigationTitle("Choose gate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.t("Cancel")) { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

extension AccessRoute: Identifiable {
    public var id: Int { recordId }
}
