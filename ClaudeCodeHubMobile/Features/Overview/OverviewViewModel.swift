import Foundation

@MainActor
final class OverviewViewModel: ObservableObject {
    @Published private(set) var quota: QuotaSummary?
    @Published private(set) var stats: StatsSummary?
    @Published private(set) var availableModels: [String] = []
    @Published private(set) var availableEndpoints: [String] = []
    @Published private(set) var serverTimeZone: String?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let sessionStore: SessionStore
    private var hasLoaded = false

    var resolvedTimeZone: TimeZone? { AppFormatters.resolvedTimeZone(serverTimeZone) }

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
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
            if sessionStore.isAdmin {
                async let statsRequest = client.getDashboardOverview()
                async let modelsRequest = client.getDashboardAvailableModels()
                async let logsRequest = client.getDashboardUsageLogs(limit: 100, offset: 0)

                quota = QuotaSummary(status: "admin", quota: nil, remaining: nil, used: nil, expiresAt: nil)
                stats = try await statsRequest
                availableModels = try await modelsRequest
                availableEndpoints = Array(Set((try await logsRequest).records.compactMap(\.endpoint))).sorted()
            } else {
                async let quotaRequest = client.getQuota()
                async let statsRequest = client.getStatsSummary()
                async let modelsRequest = client.getAvailableModels()
                async let endpointsRequest = client.getAvailableEndpoints()

                quota = try await quotaRequest
                stats = try await statsRequest
                availableModels = try await modelsRequest
                availableEndpoints = try await endpointsRequest
            }
        } catch {
            if sessionStore.handleAPIError(error) { return }
            errorMessage = APIError.userMessage(for: error)
        }
    }
}
