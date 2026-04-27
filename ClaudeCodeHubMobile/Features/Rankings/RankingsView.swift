import SwiftUI

struct RankingsView: View {
    @StateObject private var viewModel: RankingsViewModel

    init(sessionStore: SessionStore) {
        _viewModel = StateObject(wrappedValue: RankingsViewModel(sessionStore: sessionStore))
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

                Section {
                    Picker("Scope", selection: Binding(
                        get: { viewModel.scope },
                        set: { viewModel.setScope($0) }
                    )) {
                        Label("Users", systemImage: "person.2").tag(DashboardLeaderboardScope.user)
                        Label("Providers", systemImage: "point.3.connected.trianglepath.dotted").tag(DashboardLeaderboardScope.provider)
                        Label("Models", systemImage: "cpu").tag(DashboardLeaderboardScope.model)
                    }
                    .pickerStyle(.segmented)

                    Picker("Period", selection: Binding(
                        get: { viewModel.period },
                        set: { viewModel.setPeriod($0) }
                    )) {
                        ForEach(DashboardLeaderboardPeriod.allCases) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                } header: {
                    Text("Ranking Controls")
                }

                Section {
                    if viewModel.entries.isEmpty && !viewModel.isLoading {
                        ContentUnavailableView("No ranking data", systemImage: "chart.bar.doc.horizontal", description: Text("Try another period or refresh."))
                    } else {
                        ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
                            RankingRow(rank: index + 1, entry: entry, showsModelBreakdown: viewModel.scope == .provider)
                        }
                    }
                } header: {
                    HStack {
                        Text(viewModel.scope.title)
                        Spacer()
                        Text(viewModel.period.displayName)
                    }
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.entries.isEmpty {
                    ProgressView("Loading rankings…")
                }
            }
            .navigationTitle("Rankings")
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
        }
    }
}

private struct RankingRow: View {
    let rank: Int
    let entry: DashboardLeaderboardEntry
    let showsModelBreakdown: Bool

    private var medalColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("#\(rank)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(medalColor)
                    .frame(width: 34, height: 34)
                    .background(medalColor.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name)
                        .font(.headline)
                        .lineLimit(1)
                    HStack(spacing: 10) {
                        Label(AppFormatters.integer(entry.totalRequests), systemImage: "arrow.left.arrow.right")
                        Label(AppFormatters.integer(entry.totalTokens), systemImage: "number")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(AppFormatters.money(entry.totalCost))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    if let successRate = entry.successRate {
                        Text(AppFormatters.percent(successRate))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }
            }

            if showsModelBreakdown && !entry.modelStats.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(entry.modelStats.prefix(3)) { model in
                        HStack {
                            Text(model.name)
                                .lineLimit(1)
                            Spacer()
                            Text("\(AppFormatters.integer(model.totalRequests)) · \(AppFormatters.money(model.totalCost))")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
                .padding(.leading, 46)
            }
        }
        .padding(.vertical, 4)
    }
}

private extension DashboardLeaderboardScope {
    var title: String {
        switch self {
        case .user: return "User Rankings"
        case .provider: return "Provider Rankings"
        case .model: return "Model Rankings"
        }
    }
}
