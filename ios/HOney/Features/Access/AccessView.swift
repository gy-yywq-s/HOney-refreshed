//
//  AccessView.swift
//  HOney — Access tab in the legacy grammar: Apply Permit card + All Permits
//  list scroll above a fixed bottom action dock (Commuter / Exit Permit cards
//  that expand into the gate picker — the app's single real material).
//  Behavior is the P0 flow: confirm before any gate opens; errors stay on
//  this screen.
//

import SwiftUI

struct AccessView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: AccessViewModel?

    // Open-gate flow
    @State private var pendingRoute: AccessRoute?
    @State private var isGatePickerExpanded = false
    /// Route + gate captured together at gate-choice time, so the collapse
    /// gesture can never race the confirmation (legacy AccessConfirmation).
    @State private var confirmRequest: (route: AccessRoute, gate: GateChoice)?
    @State private var isPermitPickerPresented = false
    @State private var isQuickApplyPromptPresented = false

    // Apply-permit draft
    @State private var permitStartDate = Date()
    @State private var permitEndDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    @State private var permitReason = "Exit"
    @State private var editingPermitField: PermitDraftField?

    private let maxPreviewPermitsCollapsed = 3
    @State private var isPermitListExpanded = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    AppLoadingState(title: "Loading access")
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if viewModel == nil { viewModel = AccessViewModel(services: model.services) }
                await viewModel?.refresh()
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: AccessViewModel) -> some View {
        GeometryReader { proxy in
            VStack(spacing: 12) {
                ScrollView {
                    VStack(spacing: 12) {
                        permitTemplate(vm)
                        permitListPreview(vm)
                    }
                    .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
                    .padding(.top, 8)
                }
                .scrollIndicators(.hidden)
                .refreshable { await vm.refresh() }

                fixedAccessStatus(vm)

                accessSection(vm)
                    .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
                    .padding(.bottom, 12)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .simultaneousGesture(TapGesture().onEnded { collapseGatePicker() })
        .confirmationDialog(
            "Open the \(confirmRequest?.gate.title ?? "gate")?",
            isPresented: Binding(
                get: { confirmRequest != nil },
                set: { if !$0 { confirmRequest = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Open \(confirmRequest?.gate.title ?? "gate")") {
                if let request = confirmRequest {
                    Task { await vm.openGate(route: request.route, gate: request.gate) }
                }
                confirmRequest = nil
                pendingRoute = nil
            }
            Button("Cancel", role: .cancel) { confirmRequest = nil }
        } message: {
            Text("This opens a physical gate. Only do this when you are there.")
        }
        .confirmationDialog("Choose Permit", isPresented: $isPermitPickerPresented, titleVisibility: .visible) {
            ForEach(vm.approvedPermits) { permit in
                Button(permitPickerLabel(permit)) {
                    beginGateFlow(route: .permit(recordId: permit.recordId))
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Select the permit to use for this gate opening.")
        }
        .confirmationDialog("No Active Permit", isPresented: $isQuickApplyPromptPresented, titleVisibility: .visible) {
            Button("Quick Apply") {
                Task { await vm.applyPermit(start: Date(), end: Date().addingTimeInterval(2 * 3600), reason: cleanedReason) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("No approved exit permit is available. Apply with the current draft first?")
        }
        .sheet(item: $editingPermitField) { field in
            PermitDraftEditor(
                field: field,
                startDate: $permitStartDate,
                endDate: $permitEndDate,
                reason: $permitReason
            )
            .presentationDetents([field == .reason ? .fraction(0.28) : .medium])
            .presentationBackground(Palette.background)
        }
    }

    // MARK: - Apply Permit (legacy permitTemplate)

    private func permitTemplate(_ vm: AccessViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Apply Permit")
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundStyle(Palette.navy)

                Spacer()

                Text(Self.dateFormatter.string(from: permitStartDate))
                    .font(AppTheme.Typography.captionSemibold)
                    .foregroundStyle(Palette.navy.opacity(0.55))
            }

            HStack(spacing: 8) {
                EditablePermitField(
                    title: "Start",
                    value: Self.timeFormatter.string(from: permitStartDate)
                ) {
                    editingPermitField = .start
                }

                EditablePermitField(
                    title: "End",
                    value: Self.timeFormatter.string(from: permitEndDate),
                    badge: Calendar.current.isDate(permitEndDate, inSameDayAs: permitStartDate) ? nil : "+1"
                ) {
                    editingPermitField = .end
                }
            }

            EditablePermitField(title: "Reason", value: permitReason) {
                editingPermitField = .reason
            }

            Button {
                Task { await vm.applyPermit(start: permitStartDate, end: permitEndDate, reason: cleanedReason) }
            } label: {
                Label(vm.isWorking ? "Applying" : "Apply", systemImage: "plus.circle.fill")
                    .font(AppTheme.Typography.subheadlineSemibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Palette.ocean, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .disabled(vm.isWorking)
        }
        .padding(14)
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(Palette.line, lineWidth: 1)
        )
    }

    private var cleanedReason: String {
        let cleaned = permitReason.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Exit" : cleaned
    }

    // MARK: - All Permits (legacy permitListPreview)

    private func permitListPreview(_ vm: AccessViewModel) -> some View {
        let permits = vm.permits
        let visible = isPermitListExpanded ? permits : Array(permits.prefix(maxPreviewPermitsCollapsed))

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("All Permits")
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundStyle(Palette.navy)

                Spacer()

                if permits.count > maxPreviewPermitsCollapsed {
                    Image(systemName: isPermitListExpanded ? "chevron.up" : "chevron.down")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(Palette.ocean)
                }
            }

            if vm.isLoading && permits.isEmpty {
                AppLoadingState(title: "Loading permits")
            } else if visible.isEmpty {
                AppEmptyState(title: "No permits loaded", systemImage: "doc.text")
            } else {
                ForEach(visible) { permit in
                    PermitListRow(permit: permit) {
                        beginGateFlow(route: .permit(recordId: permit.recordId))
                    }
                }
            }

            if permits.count > maxPreviewPermitsCollapsed {
                Text(isPermitListExpanded ? "Show Less" : "Tap anywhere to show all permits")
                    .font(AppTheme.Typography.captionSemibold)
                    .foregroundStyle(Palette.ocean)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(Palette.line, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .onTapGesture {
            guard permits.count > maxPreviewPermitsCollapsed else { return }
            withAnimation(AppTheme.Motion.fast) {
                isPermitListExpanded.toggle()
            }
        }
    }

    // MARK: - Fixed status + action dock

    private func fixedAccessStatus(_ vm: AccessViewModel) -> some View {
        VStack(spacing: 8) {
            if let banner = vm.banner {
                AppBanner(text: banner.message, style: banner.kind)
                    .onTapGesture { vm.dismissBanner() }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
    }

    private func accessSection(_ vm: AccessViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Open Gate")
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundStyle(Palette.navy)

                Text("direct to the school portal")
                    .font(AppTheme.Typography.caption2Semibold)
                    .foregroundStyle(Palette.navy.opacity(0.42))
            }

            primaryActions(vm)
        }
        .padding(.top, 4)
    }

    private func primaryActions(_ vm: AccessViewModel) -> some View {
        ZStack {
            if isGatePickerExpanded, let route = pendingRoute {
                MergedGatePicker(routeTitle: routeTitle(route)) { gate in
                    confirmRequest = (route: route, gate: gate)
                    isGatePickerExpanded = false
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.97)),
                    removal: .opacity.combined(with: .scale(scale: 1.02))
                ))
            } else {
                HStack(alignment: .top, spacing: 12) {
                    AccessActionCard(
                        title: "Commuter",
                        subtitle: "Direct access",
                        systemImage: "figure.walk.departure",
                        accent: Palette.ocean
                    ) {
                        beginGateFlow(route: .commuter)
                    }

                    AccessActionCard(
                        title: "Exit Permit",
                        subtitle: vm.approvedPermits.isEmpty ? "No active permit" : "Use active permit",
                        systemImage: "doc.text",
                        accent: Palette.ocean
                    ) {
                        beginExitPermitSelection(vm)
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 1.02)),
                    removal: .opacity.combined(with: .scale(scale: 0.97))
                ))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(AppTheme.Motion.standard, value: isGatePickerExpanded)
    }

    private func routeTitle(_ route: AccessRoute) -> String {
        switch route {
        case .commuter: return "Commuter"
        case .permit: return "Exit Permit"
        }
    }

    private func beginGateFlow(route: AccessRoute) {
        pendingRoute = route
        withAnimation(AppTheme.Motion.standard) {
            isGatePickerExpanded = true
        }
    }

    private func beginExitPermitSelection(_ vm: AccessViewModel) {
        let permits = vm.approvedPermits
        if permits.isEmpty {
            isQuickApplyPromptPresented = true
        } else if permits.count == 1, let permit = permits.first {
            beginGateFlow(route: .permit(recordId: permit.recordId))
        } else {
            isPermitPickerPresented = true
        }
    }

    private func collapseGatePicker() {
        guard isGatePickerExpanded else { return }
        withAnimation(AppTheme.Motion.standard) {
            isGatePickerExpanded = false
        }
    }

    private func permitPickerLabel(_ permit: PortalPermitRow) -> String {
        let times = PermitTimeText.rangeText(start: permit.startTime, end: permit.endTime)
        if times.isEmpty {
            return permit.note?.isEmpty == false ? permit.note! : "Permit #\(permit.recordId)"
        }
        return times
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()
}

// MARK: - Permit time formatting (portal "yyyy-MM-dd HH:mm:ss" strings)

private enum PermitTimeText {
    static func dateText(_ timestamp: String?) -> String {
        guard let timestamp, timestamp.count >= 10 else { return "" }
        return String(timestamp.prefix(10))
    }

    static func timeText(_ timestamp: String?) -> String {
        guard let timestamp, timestamp.count >= 16 else { return "" }
        let start = timestamp.index(timestamp.startIndex, offsetBy: 11)
        let end = timestamp.index(timestamp.startIndex, offsetBy: 16)
        return String(timestamp[start..<end])
    }

    static func rangeText(start: String?, end: String?) -> String {
        let startText = timeText(start)
        let endText = timeText(end)
        guard !startText.isEmpty || !endText.isEmpty else { return "" }
        return "\(startText)–\(endText)"
    }
}

// MARK: - Permit list row (ported legacy PermitListRow)

private struct PermitListRow: View {
    let permit: PortalPermitRow
    let onOpen: () -> Void

    private var statusText: String {
        permit.statusName ?? (permit.isApproved ? "Approved" : "Pending")
    }

    private var statusColor: Color {
        permit.isApproved ? Palette.success : Palette.warning
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(permit.note?.isEmpty == false ? permit.note! : "Exit permit")
                    .font(AppTheme.Typography.subheadlineSemibold)
                    .foregroundStyle(Palette.navy)

                Text("\(PermitTimeText.dateText(permit.startTime)) · \(PermitTimeText.rangeText(start: permit.startTime, end: permit.endTime))")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Palette.navy.opacity(0.62))
            }

            Spacer()

            if permit.isApproved {
                VStack(alignment: .trailing, spacing: 6) {
                    Text(statusText)
                        .font(AppTheme.Typography.caption2Bold)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.14), in: Capsule())

                    Button {
                        onOpen()
                    } label: {
                        Label("Open", systemImage: "lock.open")
                            .font(AppTheme.Typography.captionBold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Palette.ocean, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }
            } else {
                Text(statusText)
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.14), in: Capsule())
            }
        }
        .padding(12)
        .background(Palette.mist.opacity(0.46), in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }
}

// MARK: - Editable permit fields (ported legacy)

private enum PermitDraftField: String, Identifiable {
    case start
    case end
    case reason

    var id: String { rawValue }

    var title: String {
        switch self {
        case .start:
            return "Start Time"
        case .end:
            return "End Time"
        case .reason:
            return "Reason"
        }
    }
}

private struct EditablePermitField: View {
    let title: String
    let value: String
    var badge: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppTheme.Typography.caption2Bold)
                        .foregroundStyle(Palette.navy.opacity(0.54))

                    Text(value)
                        .font(AppTheme.Typography.captionSemibold)
                        .foregroundStyle(Palette.navy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }

                Spacer(minLength: 4)

                if let badge {
                    Text(badge)
                        .font(AppTheme.Typography.caption2Bold)
                        .foregroundStyle(Palette.ocean)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Palette.ocean.opacity(0.12), in: Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(AppTheme.Typography.caption2Bold)
                    .foregroundStyle(Palette.navy.opacity(0.28))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Palette.mist.opacity(0.72), in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        }
        .buttonStyle(.plain)
    }
}

private struct PermitDraftEditor: View {
    @Environment(\.dismiss) private var dismiss
    let field: PermitDraftField
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var reason: String

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background
                    .ignoresSafeArea()

                editorContent
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(Palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle(field.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .dismissKeyboardOnTap()
    }

    @ViewBuilder
    private var editorContent: some View {
        switch field {
        case .start:
            VStack(alignment: .leading, spacing: 16) {
                DatePicker("Start", selection: $startDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .background(Color.clear)
                    .frame(maxWidth: .infinity)
                    .onChange(of: startDate) { _, newStart in
                        if endDate <= newStart {
                            endDate = Calendar.current.date(byAdding: .hour, value: 2, to: newStart) ?? newStart
                        }
                    }

                editorHint("the date always stays on today.")
            }

        case .end:
            VStack(alignment: .leading, spacing: 16) {
                DatePicker("End", selection: $endDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .background(Color.clear)
                    .frame(maxWidth: .infinity)
                    .onChange(of: endDate) { _, newEnd in
                        if newEnd <= startDate {
                            endDate = Calendar.current.date(byAdding: .day, value: 1, to: newEnd) ?? newEnd
                        }
                    }

                editorHint("ends after it starts — that is the whole rule.")
            }

        case .reason:
            VStack(alignment: .leading, spacing: 12) {
                TextField("Reason", text: $reason)
                    .font(AppTheme.Typography.subheadlineSemibold)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                            .stroke(Palette.line, lineWidth: 1)
                    )

                editorHint("a word or two is plenty. 简单写写就行。")
            }
        }
    }

    private func editorHint(_ text: String) -> some View {
        Text(text)
            .font(AppTheme.Typography.captionMedium)
            .foregroundStyle(Palette.navy.opacity(0.52))
    }
}

// MARK: - Action dock cards + gate picker (ported legacy)

private struct AccessActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            collapsedContent
                .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(height: 124)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .fill(.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(Palette.line, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }

    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                iconView

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundStyle(Palette.navy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(subtitle)
                        .font(AppTheme.Typography.captionMedium)
                        .foregroundStyle(Palette.navy.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iconView: some View {
        Image(systemName: systemImage)
            .font(AppTheme.Typography.subheadlineBold)
            .foregroundStyle(accent)
            .frame(width: 34, height: 34)
            .background(Palette.mist.opacity(0.82), in: RoundedRectangle(cornerRadius: AppTheme.Radius.small))
    }
}

private struct MergedGatePicker: View {
    let routeTitle: String
    let action: (GateChoice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(routeTitle)
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundStyle(Palette.navy)

                Text("Choose gate")
                    .font(AppTheme.Typography.captionSemibold)
                    .foregroundStyle(Palette.navy.opacity(0.50))
            }

            HStack(spacing: 10) {
                ForEach(GateChoice.allCases) { gate in
                    Button {
                        action(gate)
                    } label: {
                        Text(gate == .front ? "Front" : "Back")
                            .font(AppTheme.Typography.gateChoice)
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                            .background(Palette.ocean.opacity(0.18), in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                                    .stroke(Palette.ocean.opacity(0.24), lineWidth: 1)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.navy.opacity(0.78))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(Palette.ocean.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Palette.navy.opacity(0.08), radius: 18, x: 0, y: 8)
    }
}
