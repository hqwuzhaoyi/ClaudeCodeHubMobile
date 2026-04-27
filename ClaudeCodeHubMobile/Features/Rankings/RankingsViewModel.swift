import Foundation

@MainActor
final class RankingsViewModel: ObservableObject {
    @Published private(set) var entries: [DashboardLeaderboardEntry] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var scope: DashboardLeaderboardScope = .user
    @Published var period: DashboardLeaderboardPeriod = .daily

    private let sessionStore: SessionStore
    private var hasLoaded = false

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
        guard sessionStore.isAdmin else {
            errorMessage = "Rankings are available for admin accounts."
            return
        }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            entries = try await client.getDashboardLeaderboard(scope: scope, period: period)
        } catch {
            if sessionStore.handleAPIError(error) { return }
            errorMessage = APIError.userMessage(for: error)
        }
    }

    func setScope(_ value: DashboardLeaderboardScope) {
        guard scope != value else { return }
        scope = value
        Task { await refresh() }
    }

    func setPeriod(_ value: DashboardLeaderboardPeriod) {
        guard period != value else { return }
        period = value
        Task { await refresh() }
    }
}
