import SwiftUI

struct OverviewView: View {
    @StateObject private var viewModel: OverviewViewModel

    init(sessionStore: SessionStore) {
        _viewModel = StateObject(wrappedValue: OverviewViewModel(sessionStore: sessionStore))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if let errorMessage = viewModel.errorMessage {
                        ErrorBanner(message: errorMessage) {
                            Task { await viewModel.refresh() }
                        }
                    }

                    QuotaCard(quota: viewModel.quota, timeZone: viewModel.resolvedTimeZone)
                    StatsCard(stats: viewModel.stats)
                    BreakdownCard(title: "Top Models", items: viewModel.stats?.topModels ?? [], fallbackValues: viewModel.availableModels)
                    BreakdownCard(title: "Top Endpoints", items: viewModel.stats?.topEndpoints ?? [], fallbackValues: viewModel.availableEndpoints)

                    if let serverTimeZone = viewModel.serverTimeZone, !serverTimeZone.isEmpty {
                        Label("Server timezone: \(serverTimeZone)", systemImage: "clock")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            .overlay {
                if viewModel.isLoading && viewModel.quota == nil && viewModel.stats == nil {
                    ProgressView("Loading overview…")
                }
            }
            .navigationTitle("Overview")
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
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }
}

private struct QuotaCard: View {
    let quota: QuotaSummary?
    let timeZone: TimeZone?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Account Status", systemImage: "person.text.rectangle")
                        .font(.headline)
                    Spacer()
                    statusBadge
                }

                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                    GridRow {
                        Metric(label: "Quota", value: AppFormatters.number(quota?.quota))
                        Metric(label: "Remaining", value: AppFormatters.number(quota?.remaining))
                    }
                    GridRow {
                        Metric(label: "Used", value: AppFormatters.number(quota?.used))
                        Metric(label: "Expires", value: AppFormatters.dateTime(quota?.expiresAt, timeZone: timeZone))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let status = quota?.status ?? "Unknown"
        Text(status.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background((quota?.isActive == false ? Color.red : Color.green).opacity(0.15), in: Capsule())
            .foregroundStyle(quota?.isActive == false ? .red : .green)
    }
}

private struct StatsCard: View {
    let stats: StatsSummary?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Recent Usage", systemImage: "chart.bar.xaxis")
                        .font(.headline)
                    Spacer()
                    Text(stats?.rangeLabel ?? "Recent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                    GridRow {
                        Metric(label: "Requests", value: AppFormatters.integer(stats?.totalRequests))
                        Metric(label: "Cost", value: AppFormatters.money(stats?.totalCost))
                    }
                    GridRow {
                        Metric(label: "Tokens", value: AppFormatters.integer(stats?.totalTokens))
                        Metric(label: "Models", value: AppFormatters.integer(stats?.topModels.count))
                    }
                }
            }
        }
    }
}

private struct BreakdownCard: View {
    let title: String
    let items: [BreakdownItem]
    let fallbackValues: [String]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)

                if !items.isEmpty {
                    ForEach(items.prefix(5)) { item in
                        HStack {
                            Text(item.label)
                                .lineLimit(1)
                            Spacer()
                            Text(item.count.map(AppFormatters.integer) ?? AppFormatters.number(item.value))
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                } else if !fallbackValues.isEmpty {
                    FlowValues(values: Array(fallbackValues.prefix(8)))
                } else {
                    ContentUnavailableView("No data yet", systemImage: "tray")
                        .frame(minHeight: 80)
                }
            }
        }
    }
}

private struct Metric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
