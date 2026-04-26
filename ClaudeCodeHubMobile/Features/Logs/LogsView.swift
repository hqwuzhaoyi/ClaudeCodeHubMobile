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
                            UsageLogRow(log: log, timeZone: viewModel.resolvedTimeZone)
                                .onAppear {
                                    Task { await viewModel.loadMoreIfNeeded(currentLog: log) }
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
                        Text("Recent Records")
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
        }
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

    private var isSuccess: Bool {
        if let statusCode { return (200..<400).contains(statusCode) }
        let normalized = status.lowercased()
        return ["success", "succeeded", "ok", "complete", "completed", "done"].contains(normalized) || normalized.hasPrefix("2")
    }

    var body: some View {
        Text(status.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((isSuccess ? Color.green : Color.orange).opacity(0.15), in: Capsule())
            .foregroundStyle(isSuccess ? .green : .orange)
    }
}
