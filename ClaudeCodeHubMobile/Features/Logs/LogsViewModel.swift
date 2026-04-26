import Foundation

@MainActor
final class LogsViewModel: ObservableObject {
    @Published private(set) var logs: [UsageLog] = []
    @Published private(set) var availableModels: [String] = []
    @Published private(set) var availableEndpoints: [String] = []
    @Published private(set) var serverTimeZone: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMorePages = false
    @Published var selectedModel = "All"
    @Published var selectedEndpoint = "All"
    @Published var selectedStatus = "All"
    @Published var errorMessage: String?

    private let sessionStore: SessionStore
    private var hasLoaded = false
    private var nextCursor: UsageLogsCursor?
    private var nextOffset = 0
    private let pageSize = 100

    let statusOptions = ["All", "success", "failed", "unknown"]

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    var modelOptions: [String] { ["All"] + availableModels }
    var endpointOptions: [String] { ["All"] + availableEndpoints }
    var resolvedTimeZone: TimeZone? { AppFormatters.resolvedTimeZone(serverTimeZone) }

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
        guard let client = sessionStore.client else {
            errorMessage = APIError.missingSession.message
            return
        }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            serverTimeZone = try await client.getServerTimeZone()
            let response: UsageLogsResponse
            if sessionStore.isAdmin {
                async let logsRequest = client.getDashboardUsageLogs(limit: pageSize, offset: 0)
                async let modelsRequest = client.getDashboardAvailableModels()
                response = try await logsRequest
                availableModels = try await modelsRequest
                availableEndpoints = Array(Set(response.records.compactMap(\.endpoint))).sorted()
            } else {
                async let logsRequest = client.getUsageLogs(limit: pageSize, offset: 0)
                async let modelsRequest = client.getAvailableModels()
                async let endpointsRequest = client.getAvailableEndpoints()
                response = try await logsRequest
                availableModels = try await modelsRequest
                availableEndpoints = try await endpointsRequest
            }

            logs = sorted(response.records)
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
                response = try await client.getDashboardUsageLogs(limit: pageSize, offset: nextOffset)
            } else {
                response = try await client.getUsageLogs(limit: pageSize, offset: nextOffset, cursor: nextCursor)
            }
            let existingIDs = Set(logs.map(\.id))
            let newRecords = response.records.filter { !existingIDs.contains($0.id) }
            logs = sorted(logs + newRecords)
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

    private func normalizeSelections() {
        if selectedModel != "All", !availableModels.contains(selectedModel) { selectedModel = "All" }
        if selectedEndpoint != "All", !availableEndpoints.contains(selectedEndpoint) { selectedEndpoint = "All" }
    }
}
