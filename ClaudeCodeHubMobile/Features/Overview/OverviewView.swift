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

                    if viewModel.isAdmin {
                        AdminDashboardHome(viewModel: viewModel)
                    } else {
                        QuotaCard(quota: viewModel.quota, timeZone: viewModel.resolvedTimeZone)
                        StatsCard(stats: viewModel.stats)
                        BreakdownCard(title: "Top Models", items: viewModel.stats?.topModels ?? [], fallbackValues: viewModel.availableModels)
                        BreakdownCard(title: "Top Endpoints", items: viewModel.stats?.topEndpoints ?? [], fallbackValues: viewModel.availableEndpoints)
                    }

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

private struct AdminDashboardHome: View {
    @ObservedObject var viewModel: OverviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminBentoMetrics(stats: viewModel.stats)

            LiveSessionsHomeCard(sessions: viewModel.visibleActiveSessions, totalCount: viewModel.activeSessions.count)

            CircuitBreakerHomeCard(providers: viewModel.circuitBreakerProviders, timeZone: viewModel.resolvedTimeZone)

            LeaderboardMiniCard(title: "User Rankings", icon: "person.2", accent: .blue, entries: viewModel.userLeaderboard)
            LeaderboardMiniCard(title: "Provider Rankings", icon: "point.3.connected.trianglepath.dotted", accent: .purple, entries: viewModel.providerLeaderboard)
            LeaderboardMiniCard(title: "Model Rankings", icon: "cpu", accent: .green, entries: viewModel.modelLeaderboard)
        }
    }
}

private struct CircuitBreakerHomeCard: View {
    let providers: [CircuitBreakerProvider]
    let timeZone: TimeZone?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Circuit Breakers", systemImage: "bolt.trianglebadge.exclamationmark")
                        .font(.headline)
                    Spacer()
                    Text(providers.isEmpty ? "Healthy" : "\(providers.count) open")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((providers.isEmpty ? Color.green : Color.orange).opacity(0.14), in: Capsule())
                        .foregroundStyle(providers.isEmpty ? .green : .orange)
                }

                if providers.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No providers are currently fused")
                                .font(.subheadline.weight(.medium))
                            Text("Open or half-open provider circuits will appear here.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(providers.prefix(5)) { item in
                        CircuitBreakerProviderRow(item: item, timeZone: timeZone)
                    }
                    if providers.count > 5 {
                        Text("+ \(providers.count - 5) more fused providers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct CircuitBreakerProviderRow: View {
    let item: CircuitBreakerProvider
    let timeZone: TimeZone?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(.orange)
                .frame(width: 9, height: 9)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.provider.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.health.displayState)
                    Text("·")
                    Text("\(item.health.failureCount) failures")
                    if let providerType = item.provider.providerType {
                        Text("·")
                        Text(providerType)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let lastFailureTime = item.health.lastFailureTime {
                    Text("Last failure \(AppFormatters.dateTime(lastFailureTime, timeZone: timeZone))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(item.provider.groupTag ?? "—")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct AdminBentoMetrics: View {
    let stats: StatsSummary?

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                AdminMetricCard(
                    title: "Concurrent",
                    value: AppFormatters.integer(stats?.concurrentSessions),
                    icon: "wave.3.right",
                    accent: .green,
                    comparison: stats?.recentMinuteRequests.map { "\($0) RPM" } ?? "RPM —"
                )
                AdminMetricCard(
                    title: "Today Requests",
                    value: AppFormatters.integer(stats?.totalRequests),
                    icon: "chart.line.uptrend.xyaxis",
                    accent: .blue,
                    comparison: comparison(current: Double(stats?.totalRequests ?? 0), previous: Double(stats?.yesterdaySamePeriodRequests ?? 0))
                )
            }
            GridRow {
                AdminMetricCard(
                    title: "Today Cost",
                    value: AppFormatters.money(stats?.totalCost),
                    icon: "creditcard",
                    accent: .orange,
                    comparison: comparison(current: stats?.totalCost ?? 0, previous: stats?.yesterdaySamePeriodCost ?? 0)
                )
                AdminMetricCard(
                    title: "Avg Response",
                    value: AppFormatters.duration(milliseconds: stats?.avgResponseTimeMs),
                    icon: "timer",
                    accent: .purple,
                    comparison: comparison(
                        current: Double(stats?.avgResponseTimeMs ?? 0),
                        previous: Double(stats?.yesterdaySamePeriodAvgResponseTimeMs ?? 0),
                        inverted: true
                    )
                )
            }
        }
    }

    private func comparison(current: Double, previous: Double, inverted: Bool = false) -> String {
        guard previous > 0 else { return "vs yesterday —" }
        var percent = ((current - previous) / previous) * 100
        if inverted { percent *= -1 }
        let prefix = percent > 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.0f", percent))% vs yesterday"
    }
}

private struct AdminMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let accent: Color
    let comparison: String

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                        .frame(width: 28, height: 28)
                        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(value)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(comparison)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(comparison.contains("+") ? .green : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(minHeight: 104, alignment: .topLeading)
        }
    }
}

private struct LiveSessionsHomeCard: View {
    let sessions: [ActiveSession]
    let totalCount: Int

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Active Sessions", systemImage: "terminal")
                        .font(.headline)
                    Spacer()
                    HStack(spacing: 5) {
                        Circle().fill(.red.opacity(0.35)).frame(width: 8, height: 8)
                        Circle().fill(.orange.opacity(0.35)).frame(width: 8, height: 8)
                        Circle().fill(.green.opacity(0.45)).frame(width: 8, height: 8)
                    }
                }

                if sessions.isEmpty {
                    ContentUnavailableView("No active sessions", systemImage: "bolt.horizontal.circle")
                        .frame(minHeight: 110)
                } else {
                    ForEach(sessions) { session in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(session.isLive ? Color.green : Color.secondary.opacity(0.45))
                                .frame(width: 8, height: 8)
                            Text("#\(session.sessionId.suffix(6))")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Text(session.userName ?? "Unknown")
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Spacer()
                            Text(session.displayStatus.replacingOccurrences(of: "_", with: " ").uppercased())
                                .font(.caption2.weight(.bold).monospaced())
                                .foregroundStyle(session.isLive ? .green : .secondary)
                        }
                    }
                }

                if totalCount > sessions.count {
                    Text("+ \(totalCount - sessions.count) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct LeaderboardMiniCard: View {
    let title: String
    let icon: String
    let accent: Color
    let entries: [DashboardLeaderboardEntry]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.headline)
                    Spacer()
                    Text("Daily")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if entries.isEmpty {
                    ContentUnavailableView("No data yet", systemImage: "chart.bar")
                        .frame(minHeight: 96)
                } else {
                    ForEach(Array(entries.prefix(3).enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(accent)
                                .frame(width: 24, height: 24)
                                .background(accent.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text("\(AppFormatters.integer(entry.totalRequests)) requests · \(AppFormatters.integer(entry.totalTokens)) tokens")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(AppFormatters.money(entry.totalCost))
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
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
