import SwiftUI

struct LogsView: View {
    @StateObject private var viewModel: LogsViewModel

    init(sessionStore: SessionStore) {
        _viewModel = StateObject(wrappedValue: LogsViewModel(sessionStore: sessionStore))
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

                if viewModel.isAdmin {
                    AdminMonitoringSection(viewModel: viewModel)
                    AdminUsageSearchSection(viewModel: viewModel)
                }

                Section {
                    Picker("Model", selection: $viewModel.selectedModel) {
                        ForEach(viewModel.modelOptions, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Endpoint", selection: $viewModel.selectedEndpoint) {
                        ForEach(viewModel.endpointOptions, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Status", selection: $viewModel.selectedStatus) {
                        ForEach(viewModel.statusOptions, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                } header: {
                    Text("Filters")
                }

                Section {
                    if viewModel.filteredLogs.isEmpty && !viewModel.isLoading {
                        ContentUnavailableView("No matching usage records", systemImage: "doc.text.magnifyingglass", description: Text(viewModel.hasMorePages ? "Load more pages or clear filters." : "Try refreshing or clearing filters."))
                    } else {
                        ForEach(viewModel.filteredLogs) { log in
                            if viewModel.isAdmin {
                                AdminUsageLogRow(log: log, timeZone: viewModel.resolvedTimeZone)
                                    .newRecordHighlight(isActive: viewModel.isHighlighted(log))
                                    .onAppear {
                                        Task { await viewModel.loadMoreIfNeeded(currentLog: log) }
                                    }
                            } else {
                                UsageLogRow(log: log, timeZone: viewModel.resolvedTimeZone)
                                    .newRecordHighlight(isActive: viewModel.isHighlighted(log))
                                    .onAppear {
                                        Task { await viewModel.loadMoreIfNeeded(currentLog: log) }
                                    }
                            }
                        }
                    }

                    if viewModel.hasMorePages {
                        Button {
                            Task { await viewModel.loadMore() }
                        } label: {
                            HStack {
                                Text("Load More")
                                Spacer()
                                if viewModel.isLoadingMore {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(viewModel.isLoadingMore)
                    }
                } header: {
                    HStack {
                        Text(viewModel.hasAdminSearch ? "Search Results" : "Recent Records")
                        Spacer()
                        Text("\(viewModel.filteredLogs.count) shown")
                    }
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.logs.isEmpty {
                    ProgressView("Loading logs…")
                }
            }
            .navigationTitle("Logs")
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
            .task {
                await viewModel.autoRefreshLoop()
            }
        }
    }
}

private struct AdminUsageSearchSection: View {
    @ObservedObject var viewModel: LogsViewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("User, key, provider, model, session…", text: $viewModel.adminSearchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit { submit() }

                if viewModel.hasAdminSearch {
                    Button {
                        viewModel.adminSearchText = ""
                        submit()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }

            Button {
                submit()
            } label: {
                Label("Search usage records", systemImage: "line.3.horizontal.decrease.circle")
            }
            .disabled(viewModel.isLoading)
        } header: {
            Text("Usage Search")
        } footer: {
            Text("Search is sent to the dashboard usage-log API, then model, endpoint, and status filters are applied locally.")
        }
    }

    private func submit() {
        isSearchFocused = false
        Task { await viewModel.refresh() }
    }
}

private struct AdminMonitoringSection: View {
    @ObservedObject var viewModel: LogsViewModel

    var body: some View {
        Section {
            AdminKPIGrid(overview: viewModel.adminOverview, activeSessions: viewModel.activeSessions)

            Toggle(isOn: $viewModel.autoRefreshEnabled) {
                Label("Auto refresh every 5s", systemImage: viewModel.autoRefreshEnabled ? "dot.radiowaves.left.and.right" : "pause.circle")
            }
            .font(.subheadline)

            if viewModel.visibleActiveSessions.isEmpty && !viewModel.isLoading {
                ContentUnavailableView("No active sessions", systemImage: "bolt.horizontal.circle", description: Text("The dashboard monitors sessions active in the recent window."))
                    .frame(minHeight: 96)
            } else {
                ForEach(viewModel.visibleActiveSessions) { session in
                    ActiveSessionRow(session: session, timeZone: viewModel.resolvedTimeZone)
                }
            }
        } header: {
            HStack {
                Text("Live Monitoring")
                Spacer()
                if viewModel.autoRefreshEnabled {
                    Label("Live", systemImage: "circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
        } footer: {
            if viewModel.activeSessions.count > viewModel.visibleActiveSessions.count {
                Text("\(viewModel.visibleActiveSessions.count) of \(viewModel.activeSessions.count) recent sessions shown.")
            }
        }
    }
}

private struct AdminKPIGrid: View {
    let overview: StatsSummary?
    let activeSessions: [ActiveSession]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                MonitoringMetric(label: "Concurrent", value: AppFormatters.integer(overview?.concurrentSessions), icon: "person.2.wave.2")
                MonitoringMetric(label: "RPM", value: AppFormatters.integer(overview?.recentMinuteRequests), icon: "speedometer")
            }
            GridRow {
                MonitoringMetric(label: "Today Cost", value: AppFormatters.money(overview?.totalCost), icon: "creditcard")
                MonitoringMetric(label: "Recent Sessions", value: AppFormatters.integer(activeSessions.count), icon: "bolt.horizontal")
            }
            GridRow {
                MonitoringMetric(label: "Avg Response", value: AppFormatters.duration(milliseconds: overview?.avgResponseTimeMs), icon: "timer")
                MonitoringMetric(label: "Error Rate", value: AppFormatters.percent(overview?.todayErrorRate), icon: "exclamationmark.triangle")
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MonitoringMetric: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
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

private struct ActiveSessionRow: View {
    let session: ActiveSession
    let timeZone: TimeZone?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(session.isLive ? Color.green : Color.secondary.opacity(0.45))
                        .frame(width: 8, height: 8)
                    Text(session.model ?? "Unknown model")
                        .font(.headline)
                        .lineLimit(1)
                }
                Spacer(minLength: 12)
                StatusPill(status: session.displayStatus, statusCode: nil)
            }

            HStack(spacing: 6) {
                Text(session.userName ?? "Unknown user")
                Text("·")
                Text(session.keyName ?? "Unknown key")
                Text("·")
                Text(session.apiType ?? "api")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            if let providerName = session.providerName {
                Label(providerName, systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 12) {
                Label(AppFormatters.integer(session.requestCount), systemImage: "arrow.left.arrow.right")
                Label(AppFormatters.money(session.cost), systemImage: "creditcard")
                Label(AppFormatters.integer(session.totalTokens), systemImage: "number")
                Label(AppFormatters.duration(milliseconds: session.durationMs), systemImage: "timer")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(shortSession(session.sessionId, requestSequence: nil))
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

private struct AdminUsageLogRow: View {
    let log: UsageLog
    let timeZone: TimeZone?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.model ?? "Unknown model")
                        .font(.headline)
                        .lineLimit(1)
                    if let originalModel = log.originalModel, originalModel != log.model {
                        Text("requested \(originalModel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 12)
                StatusPill(status: log.displayStatus, statusCode: log.statusCode)
            }

            HStack(spacing: 6) {
                Text(log.userName ?? "Unknown user")
                Text("·")
                Text(log.keyName ?? "Unknown key")
                Text("·")
                Text(log.endpoint ?? "Unknown endpoint")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            if let providerName = log.providerName {
                Label(providerName, systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    SmallMetric(label: "Tokens", value: AppFormatters.integer(log.totalTokens), icon: "number")
                    SmallMetric(label: "Cache", value: AppFormatters.integer(cacheTokens), icon: "externaldrive")
                }
                GridRow {
                    SmallMetric(label: "Cost", value: AppFormatters.money(log.cost), icon: "creditcard")
                    SmallMetric(label: "Latency", value: AppFormatters.duration(milliseconds: log.durationMs), icon: "timer")
                }
            }

            HStack(spacing: 10) {
                Label(AppFormatters.dateTime(log.timestamp, timeZone: timeZone), systemImage: "clock")
                if let ttfbMs = log.ttfbMs {
                    Label("TTFB \(AppFormatters.duration(milliseconds: ttfbMs))", systemImage: "waveform.path.ecg")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let errorMessage = log.errorMessage, !errorMessage.isEmpty {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }

            if let sessionId = log.sessionId {
                Text(shortSession(sessionId, requestSequence: log.requestSequence))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var cacheTokens: Int? {
        let write = log.cacheCreationInputTokens ?? 0
        let read = log.cacheReadInputTokens ?? 0
        let total = write + read
        return total > 0 ? total : nil
    }
}

private struct SmallMetric: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
        }
    }
}

private struct NewRecordHighlightModifier: ViewModifier {
    let isActive: Bool
    @State private var sweepProgress = false

    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            .background {
                if isActive {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, Color.green.opacity(0.11), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: max(84, proxy.size.width * 0.32))
                        .offset(x: sweepProgress ? proxy.size.width + 36 : -120)
                        .opacity(0.95)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .leading) {
                if isActive {
                    Capsule()
                        .fill(Color.green)
                        .frame(width: 3)
                        .padding(.vertical, 5)
                        .offset(x: -9)
                        .opacity(0.85)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .listRowBackground(Color.clear)
            .onAppear { startSweepIfNeeded() }
            .onChange(of: isActive) { _, _ in startSweepIfNeeded() }
            .animation(.easeOut(duration: 0.22), value: isActive)
    }

    private func startSweepIfNeeded() {
        guard isActive else {
            sweepProgress = false
            return
        }
        sweepProgress = false
        DispatchQueue.main.async {
            withAnimation(.linear(duration: 0.7)) {
                sweepProgress = true
            }
        }
    }
}

private extension View {
    func newRecordHighlight(isActive: Bool) -> some View {
        modifier(NewRecordHighlightModifier(isActive: isActive))
    }
}

private struct UsageLogRow: View {
    let log: UsageLog
    let timeZone: TimeZone?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(log.model ?? "Unknown model")
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 12)
                StatusPill(status: log.displayStatus, statusCode: log.statusCode)
            }

            Text(log.endpoint ?? "Unknown endpoint")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 12) {
                Label(AppFormatters.dateTime(log.timestamp, timeZone: timeZone), systemImage: "clock")
                Label(AppFormatters.money(log.cost), systemImage: "creditcard")
                Label(AppFormatters.integer(log.totalTokens), systemImage: "number")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct StatusPill: View {
    let status: String
    let statusCode: Int?

    private var normalizedStatus: String {
        status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isSuccess: Bool {
        if let statusCode { return (200..<400).contains(statusCode) }
        return ["success", "succeeded", "ok", "complete", "completed", "done"].contains(normalizedStatus) || normalizedStatus.hasPrefix("2")
    }

    private var isRequesting: Bool {
        ["requesting", "in_progress", "running", "active", "streaming", "pending"].contains(normalizedStatus)
    }

    private var tint: Color {
        if isSuccess { return .green }
        if isRequesting { return .blue }
        return .orange
    }

    private var displayText: String {
        switch normalizedStatus {
        case "requesting":
            return "Requesting"
        case "in_progress":
            return "In Progress"
        default:
            return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var body: some View {
        Text(displayText)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}

private func shortSession(_ sessionId: String, requestSequence: Int?) -> String {
    let compactId: String
    if sessionId.count > 12 {
        compactId = "\(sessionId.prefix(8))…\(sessionId.suffix(4))"
    } else {
        compactId = sessionId
    }
    if let requestSequence {
        return "\(compactId) #\(requestSequence)"
    }
    return compactId
}
