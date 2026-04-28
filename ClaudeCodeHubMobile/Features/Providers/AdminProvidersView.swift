import SwiftUI

struct AdminProvidersView: View {
    @StateObject private var viewModel: AdminProvidersViewModel

    init(sessionStore: SessionStore) {
        _viewModel = StateObject(wrappedValue: AdminProvidersViewModel(sessionStore: sessionStore))
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage) {
                        Task { await viewModel.refresh() }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }

                if let writeMessage = viewModel.writeMessage {
                    Section {
                        Label(writeMessage, systemImage: "checkmark.seal.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                        GridRow {
                            ProviderMetric(label: "Enabled", value: "\(viewModel.enabledCount)/\(viewModel.providers.count)", icon: "power")
                            ProviderMetric(label: "Today Calls", value: AppFormatters.integer(viewModel.todayCalls), icon: "arrow.left.arrow.right")
                        }
                        GridRow {
                            ProviderMetric(label: "Today Cost", value: AppFormatters.money(viewModel.todayCost), icon: "creditcard")
                            ProviderMetric(label: "Open Circuits", value: AppFormatters.integer(viewModel.openCircuitProviderIds.count), icon: "bolt.trianglebadge.exclamationmark")
                        }
                    }

                    Picker("State", selection: $viewModel.filter) {
                        ForEach(AdminProvidersViewModel.Filter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Provider Management")
                } footer: {
                    Text("Provider routing details stay read-only in this mobile pass; only recovered open/half-open circuits can be reset after confirmation.")
                }

                Section {
                    if viewModel.filteredProviders.isEmpty && !viewModel.isLoading {
                        ContentUnavailableView("No providers found", systemImage: "server.rack", description: Text("Try changing the search or state filter."))
                    } else {
                        ForEach(viewModel.filteredProviders) { provider in
                            AdminProviderRow(
                                provider: provider,
                                health: viewModel.circuitStatusByProviderId[provider.id],
                                isWriting: viewModel.isWriting,
                                onResetCircuit: { health in
                                    viewModel.prepareCircuitReset(provider: provider, health: health)
                                }
                            )
                        }
                    }
                } header: {
                    HStack {
                        Text("Providers")
                        Spacer()
                        Text("\(viewModel.filteredProviders.count) shown")
                    }
                }
            }
            .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search providers, groups, models…")
            .overlay {
                if viewModel.isLoading && viewModel.providers.isEmpty {
                    ProgressView("Loading providers…")
                }
            }
            .navigationTitle("Providers")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.loadIfNeeded() }
            .alert(item: $viewModel.pendingWrite) { confirmation in
                Alert(
                    title: Text(confirmation.title),
                    message: Text("\(confirmation.message)\n\nBefore: \(confirmation.before)\nAfter: \(confirmation.after)"),
                    primaryButton: .destructive(Text(confirmation.confirmTitle)) {
                        Task { await viewModel.commitPendingWrite() }
                    },
                    secondaryButton: .cancel {
                        viewModel.cancelPendingWrite()
                    }
                )
            }
        }
    }
}

private struct AdminProviderRow: View {
    let provider: AdminProvider
    let health: ProviderHealthStatus?
    let isWriting: Bool
    let onResetCircuit: (ProviderHealthStatus) -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(provider.isEnabled ? Color.green : Color.red)
                        .frame(width: 9, height: 9)
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(provider.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(provider.groupTag ?? provider.providerType ?? "No group")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(AppFormatters.money(provider.todayTotalCostUsd))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                        Text("\(AppFormatters.integer(provider.todayCallCount)) calls")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                Label("P\(provider.priority.map(String.init) ?? "—")", systemImage: "arrow.up.arrow.down")
                Label("W\(provider.weight.map(String.init) ?? "—")", systemImage: "scalemass")
                if let costMultiplier = provider.costMultiplier {
                    Label("\(String(format: "%.2fx", costMultiplier))", systemImage: "multiply.circle")
                }
                if let providerType = provider.providerType {
                    Label(providerType, systemImage: "square.stack.3d.up")
                }
                Spacer(minLength: 8)
                if let health, health.isCircuitOpen {
                    Button(role: .destructive) {
                        onResetCircuit(health)
                    } label: {
                        Label("Reset circuit", systemImage: "arrow.counterclockwise.circle")
                    }
                    .buttonStyle(.borderless)
                    .disabled(isWriting)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if isExpanded {
                VStack(alignment: .leading, spacing: 7) {
                    if let health {
                        Label("\(health.displayState) circuit · \(health.failureCount) failures", systemImage: health.isCircuitOpen ? "bolt.trianglebadge.exclamationmark" : "checkmark.seal")
                            .foregroundStyle(health.isCircuitOpen ? .orange : .secondary)
                    }
                    if let url = provider.url {
                        Label(url, systemImage: "link")
                            .lineLimit(1)
                    }
                    if let maskedKey = provider.maskedKey {
                        Label(maskedKey, systemImage: "key")
                            .font(.caption.monospaced())
                    }
                    if let lastCallModel = provider.lastCallModel {
                        Label("Last model: \(lastCallModel)", systemImage: "cpu")
                    }
                    HStack(spacing: 10) {
                        if let rpm = provider.rpm { Text("RPM \(rpm)") }
                        if let tpm = provider.tpm { Text("TPM \(tpm)") }
                        if let rpd = provider.rpd { Text("RPD \(rpd)") }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 5)
    }
}

private struct ProviderMetric: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.purple)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
