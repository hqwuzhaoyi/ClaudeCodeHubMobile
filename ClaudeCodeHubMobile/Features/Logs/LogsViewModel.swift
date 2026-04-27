import Foundation
import SwiftUI

@MainActor
final class LogsViewModel: ObservableObject {
    @Published private(set) var logs: [UsageLog] = []
    @Published private(set) var activeSessions: [ActiveSession] = []
    @Published private(set) var adminOverview: StatsSummary?
    @Published private(set) var availableModels: [String] = []
    @Published private(set) var availableEndpoints: [String] = []
    @Published private(set) var serverTimeZone: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMorePages = false
    @Published private(set) var highlightedLogIDs: Set<String> = []
    @Published var selectedModel = "All"
    @Published var selectedEndpoint = "All"
    @Published var selectedStatus = "All"
    @Published var adminSearchText = ""
    @Published var autoRefreshEnabled = true
    @Published var errorMessage: String?

    private let sessionStore: SessionStore
    private var hasLoaded = false
    private var nextCursor: UsageLogsCursor?
    private var nextOffset = 0
    private var recentRecordHighlighter = RecentRecordHighlighter()
    private let pageSize = 100

    let statusOptions = ["All", "success", "requesting", "failed", "unknown"]

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    var modelOptions: [String] { ["All"] + availableModels }
    var endpointOptions: [String] { ["All"] + availableEndpoints }
    var resolvedTimeZone: TimeZone? { AppFormatters.resolvedTimeZone(serverTimeZone) }
    var isAdmin: Bool { sessionStore.isAdmin }
    var visibleActiveSessions: [ActiveSession] { Array(activeSessions.prefix(5)) }
    var hasAdminSearch: Bool { !adminSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var filteredLogs: [UsageLog] {
        logs.filter { log in
            (selectedModel == "All" || log.model == selectedModel) &&
            (selectedEndpoint == "All" || log.endpoint == selectedEndpoint) &&
            (selectedStatus == "All" || log.statusCategory == selectedStatus)
        }
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    func refresh() async {
        await refresh(showsLoading: true)
    }

    func refreshSilently() async {
        await refresh(showsLoading: false)
    }

    func autoRefreshLoop() async {
        guard isAdmin else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard autoRefreshEnabled, !Task.isCancelled else { continue }
            await refreshSilently()
        }
    }

    func isHighlighted(_ log: UsageLog) -> Bool {
        highlightedLogIDs.contains(log.id)
    }

    private func refresh(showsLoading: Bool) async {
        guard let client = sessionStore.client else {
            errorMessage = APIError.missingSession.message
            return
        }
        if showsLoading { isLoading = true }
        errorMessage = nil
        defer {
            if showsLoading { isLoading = false }
            hasLoaded = true
        }

        do {
            serverTimeZone = try await client.getServerTimeZone()
            let response: UsageLogsResponse
            if sessionStore.isAdmin {
                async let logsRequest = client.getDashboardUsageLogs(limit: pageSize, offset: 0, filter: dashboardFilter())
                async let modelsRequest = client.getDashboardAvailableModels()
                async let activeSessionsRequest = client.getActiveSessions()
                async let overviewRequest = client.getDashboardOverview()
                response = try await logsRequest
                availableModels = try await modelsRequest
                activeSessions = sortedActiveSessions((try? await activeSessionsRequest) ?? activeSessions)
                adminOverview = (try? await overviewRequest) ?? adminOverview
                availableEndpoints = Array(Set(response.records.compactMap(\.endpoint))).sorted()
            } else {
                async let logsRequest = client.getUsageLogs(limit: pageSize, offset: 0)
                async let modelsRequest = client.getAvailableModels()
                async let endpointsRequest = client.getAvailableEndpoints()
                response = try await logsRequest
                availableModels = try await modelsRequest
                availableEndpoints = try await endpointsRequest
                activeSessions = []
                adminOverview = nil
            }

            let sortedRecords = sorted(response.records)
            let insertedIDs = recentRecordHighlighter.update(with: sortedRecords.map(\.id))
            withAnimation(insertedIDs.isEmpty ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                logs = sortedRecords
                highlightedLogIDs = recentRecordHighlighter.highlightedIDs
            }
            scheduleHighlightClear(for: insertedIDs)
            nextOffset = response.records.count
            nextCursor = response.nextCursor
            hasMorePages = computeHasMore(from: response)
            normalizeSelections()
        } catch {
            if sessionStore.handleAPIError(error) { return }
            errorMessage = APIError.userMessage(for: error)
        }
    }

    func loadMoreIfNeeded(currentLog: UsageLog? = nil) async {
        guard hasMorePages, !isLoading, !isLoadingMore else { return }
        if let currentLog, currentLog.id != filteredLogs.last?.id { return }
        await loadMore()
    }

    func loadMore() async {
        guard let client = sessionStore.client else {
            errorMessage = APIError.missingSession.message
            return
        }
        guard hasMorePages, !isLoadingMore else { return }

        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let response: UsageLogsResponse
            if sessionStore.isAdmin {
                response = try await client.getDashboardUsageLogs(limit: pageSize, offset: nextOffset, filter: dashboardFilter())
            } else {
                response = try await client.getUsageLogs(limit: pageSize, offset: nextOffset, cursor: nextCursor)
            }
            let existingIDs = Set(logs.map(\.id))
            let newRecords = response.records.filter { !existingIDs.contains($0.id) }
            let sortedRecords = sorted(logs + newRecords)
            let insertedIDs = recentRecordHighlighter.update(with: sortedRecords.map(\.id))
            withAnimation(insertedIDs.isEmpty ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                logs = sortedRecords
                highlightedLogIDs = recentRecordHighlighter.highlightedIDs
            }
            scheduleHighlightClear(for: insertedIDs)
            nextOffset += response.records.count
            nextCursor = response.nextCursor
            hasMorePages = computeHasMore(from: response)
            if sessionStore.isAdmin {
                availableEndpoints = Array(Set(logs.compactMap(\.endpoint))).sorted()
            }
        } catch {
            if sessionStore.handleAPIError(error) { return }
            errorMessage = APIError.userMessage(for: error)
        }
    }

    private func computeHasMore(from response: UsageLogsResponse) -> Bool {
        if let hasMore = response.hasMore { return hasMore }
        if response.nextCursor != nil { return true }
        if let total = response.total { return nextOffset < total }
        return response.records.count == pageSize
    }

    private func sorted(_ records: [UsageLog]) -> [UsageLog] {
        records.sorted { left, right in
            (left.timestamp ?? .distantPast) > (right.timestamp ?? .distantPast)
        }
    }

    private func sortedActiveSessions(_ records: [ActiveSession]) -> [ActiveSession] {
        records.sorted { left, right in
            if left.isLive != right.isLive { return left.isLive && !right.isLive }
            return (left.startTime ?? .distantPast) > (right.startTime ?? .distantPast)
        }
    }

    private func scheduleHighlightClear(for ids: Set<String>) {
        guard !ids.isEmpty else { return }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            await MainActor.run {
                guard let self else { return }
                withAnimation(.easeOut(duration: 0.45)) {
                    ids.forEach { self.recentRecordHighlighter.clear($0) }
                    self.highlightedLogIDs = self.recentRecordHighlighter.highlightedIDs
                }
            }
        }
    }

    private func normalizeSelections() {
        if selectedModel != "All", !availableModels.contains(selectedModel) { selectedModel = "All" }
        if selectedEndpoint != "All", !availableEndpoints.contains(selectedEndpoint) { selectedEndpoint = "All" }
    }

    private func dashboardFilter() -> DashboardUsageLogsFilter? {
        guard sessionStore.isAdmin else { return nil }
        let filter = DashboardUsageLogsFilter(search: adminSearchText)
        return filter.search == nil && filter.userId == nil && filter.providerId == nil && filter.sessionId == nil ? nil : filter
    }
}
