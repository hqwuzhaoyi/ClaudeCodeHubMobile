import Foundation

@MainActor
final class OverviewViewModel: ObservableObject {
    @Published private(set) var quota: QuotaSummary?
    @Published private(set) var stats: StatsSummary?
    @Published private(set) var activeSessions: [ActiveSession] = []
    @Published private(set) var circuitBreakerProviders: [CircuitBreakerProvider] = []
    @Published private(set) var opsAlerts: [OpsAlert] = []
    @Published private(set) var userLeaderboard: [DashboardLeaderboardEntry] = []
    @Published private(set) var providerLeaderboard: [DashboardLeaderboardEntry] = []
    @Published private(set) var modelLeaderboard: [DashboardLeaderboardEntry] = []
    @Published private(set) var availableModels: [String] = []
    @Published private(set) var availableEndpoints: [String] = []
    @Published private(set) var serverTimeZone: String?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let sessionStore: SessionStore
    private var hasLoaded = false

    var resolvedTimeZone: TimeZone? { AppFormatters.resolvedTimeZone(serverTimeZone) }
    var isAdmin: Bool { sessionStore.isAdmin }
    var visibleActiveSessions: [ActiveSession] { Array(activeSessions.prefix(6)) }

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
                async let sessionsRequest = client.getActiveSessions()
                async let usersRequest = client.getDashboardLeaderboard(scope: .user)
                async let providersRequest = client.getDashboardLeaderboard(scope: .provider)
                async let modelsLeaderboardRequest = client.getDashboardLeaderboard(scope: .model)
                async let adminProvidersRequest = client.getAdminProviders()
                async let providerHealthRequest = client.getProvidersHealthStatus()

                quota = QuotaSummary(status: "admin", quota: nil, remaining: nil, used: nil, expiresAt: nil)
                stats = try await statsRequest
                activeSessions = sortedActiveSessions((try? await sessionsRequest) ?? [])
                userLeaderboard = (try? await usersRequest) ?? []
                providerLeaderboard = (try? await providersRequest) ?? []
                modelLeaderboard = (try? await modelsLeaderboardRequest) ?? []
                circuitBreakerProviders = OpsAlertEngine.circuitBreakerProviders(
                    providers: (try? await adminProvidersRequest) ?? [],
                    healthStatuses: (try? await providerHealthRequest) ?? []
                )
                opsAlerts = OpsAlertEngine.alerts(stats: stats, circuitBreakerProviders: circuitBreakerProviders)
                availableModels = []
                availableEndpoints = []
            } else {
                async let quotaRequest = client.getQuota()
                async let statsRequest = client.getStatsSummary()
                async let modelsRequest = client.getAvailableModels()
                async let endpointsRequest = client.getAvailableEndpoints()

                quota = try await quotaRequest
                stats = try await statsRequest
                availableModels = try await modelsRequest
                availableEndpoints = try await endpointsRequest
                activeSessions = []
                circuitBreakerProviders = []
                opsAlerts = []
                userLeaderboard = []
                providerLeaderboard = []
                modelLeaderboard = []
            }
        } catch {
            if sessionStore.handleAPIError(error) { return }
            errorMessage = APIError.userMessage(for: error)
        }
    }

    private func sortedActiveSessions(_ records: [ActiveSession]) -> [ActiveSession] {
        records.sorted { left, right in
            if left.isLive != right.isLive { return left.isLive && !right.isLive }
            return (left.startTime ?? .distantPast) > (right.startTime ?? .distantPast)
        }
    }

}
