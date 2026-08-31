//
//  AccessView.swift
//  HOney — Access tab: open-gate (commuter/permit → Front/Back → confirm) and
//  apply-permit + permits list. Errors are isolated to this screen.
//

import SwiftUI

struct AccessView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: AccessViewModel?

    // Open-gate flow
    @State private var route: RouteKind = .commuter
    @State private var selectedPermitId: Int?
    @State private var gate: GateChoice = .front
    @State private var confirming = false

    // Apply-permit flow
    @State private var showApplyForm = false
    @State private var applyStart = Date()
    @State private var applyEnd = Date().addingTimeInterval(2 * 3600)
    @State private var applyReason = ""

    private enum RouteKind: String, CaseIterable, Identifiable {
        case commuter, permit
        var id: String { rawValue }
        var title: String { self == .commuter ? "Commuter" : "Exit permit" }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    LoadingView()
                }
            }
            .screenBackground()
            .navigationTitle("Access")
            .task {
                if viewModel == nil { viewModel = AccessViewModel(services: model.services) }
                await viewModel?.refresh()
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: AccessViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if let banner = vm.banner {
                    Banner(kind: banner.kind, message: banner.message) { vm.dismissBanner() }
                }
                openGateCard(vm)
                applyPermitCard(vm)
                permitsList(vm)
            }
            .padding(Theme.Spacing.lg)
        }
        .refreshable { await vm.refresh() }
        .confirmationDialog("Open the \(gate.title)?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Open \(gate.title)") {
                Task { await vm.openGate(route: resolvedRoute(vm), gate: gate) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This opens a physical gate. Only do this when you are there.")
        }
    }

    // MARK: - Open gate

    @ViewBuilder
    private func openGateCard(_ vm: AccessViewModel) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Open the gate")

                Picker("Route", selection: $route) {
                    ForEach(RouteKind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                if route == .permit {
                    if vm.approvedPermits.isEmpty {
                        Text("No approved exit permit is available.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    } else {
                        Menu {
                            ForEach(vm.approvedPermits) { permit in
                                Button(permitLabel(permit)) { selectedPermitId = permit.recordId }
                            }
                        } label: {
                            FilterChip(
                                title: vm.approvedPermits.first { $0.recordId == selectedPermitId }.map(permitLabel) ?? "Choose permit",
                                isActive: selectedPermitId != nil
                            )
                        }
                    }
                }

                Picker("Gate", selection: $gate) {
                    ForEach(GateChoice.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                Button {
                    confirming = true
                } label: {
                    if vm.isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Label("Open \(gate.title)", systemImage: "lock.open")
                    }
                }
                .buttonStyle(HoneyPrimaryButtonStyle(enabled: canOpen(vm)))
                .disabled(!canOpen(vm) || vm.isWorking)
            }
        }
    }

    private func canOpen(_ vm: AccessViewModel) -> Bool {
        switch route {
        case .commuter: return true
        case .permit: return selectedPermitId != nil || !vm.approvedPermits.isEmpty
        }
    }

    private func resolvedRoute(_ vm: AccessViewModel) -> AccessRoute {
        switch route {
        case .commuter:
            return .commuter
        case .permit:
            let recordId = selectedPermitId ?? vm.approvedPermits.first?.recordId ?? -1
            return .permit(recordId: recordId)
        }
    }

    // MARK: - Apply permit

    @ViewBuilder
    private func applyPermitCard(_ vm: AccessViewModel) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(
                    title: "Apply for a permit",
                    actionTitle: showApplyForm ? "Quick apply" : "Details",
                    action: { showApplyForm.toggle() }
                )
                if showApplyForm {
                    DatePicker("Start", selection: $applyStart)
                        .font(Theme.Typography.body)
                    DatePicker("End", selection: $applyEnd)
                        .font(Theme.Typography.body)
                    TextField("Reason", text: $applyReason)
                        .textFieldStyle(.roundedBorder)
                    Button("Submit permit") {
                        Task { await vm.applyPermit(start: applyStart, end: applyEnd, reason: applyReason.isEmpty ? "Exit" : applyReason) }
                    }
                    .buttonStyle(HoneySecondaryButtonStyle())
                    .disabled(vm.isWorking)
                } else {
                    Text("Quick apply requests a 2-hour exit starting now.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Button("Quick apply") {
                        Task {
                            await vm.applyPermit(start: Date(), end: Date().addingTimeInterval(2 * 3600), reason: "Exit")
                        }
                    }
                    .buttonStyle(HoneySecondaryButtonStyle())
                    .disabled(vm.isWorking)
                }
            }
        }
    }

    // MARK: - Permits list

    @ViewBuilder
    private func permitsList(_ vm: AccessViewModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Your permits")
            if vm.isLoading {
                LoadingView().frame(height: 120)
            } else if vm.permits.isEmpty {
                EmptyStateView(systemImage: "doc.text", title: "No permits yet")
            } else {
                ForEach(vm.permits) { permit in
                    Card(padding: Theme.Spacing.md) {
                        ListRow(
                            title: permit.note?.isEmpty == false ? permit.note! : "Exit permit",
                            subtitle: [permit.startTime, permit.endTime].compactMap { $0 }.joined(separator: " → "),
                            trailingText: permit.statusName ?? (permit.isApproved ? "Approved" : "Pending")
                        )
                    }
                }
            }
        }
    }

    private func permitLabel(_ permit: PortalPermitRow) -> String {
        permit.note?.isEmpty == false ? permit.note! : "Permit #\(permit.recordId)"
    }
}
