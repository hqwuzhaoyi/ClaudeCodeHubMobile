import Foundation

@MainActor
final class AdminProvidersViewModel: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all
        case enabled
        case disabled

        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    @Published private(set) var providers: [AdminProvider] = []
    @Published private(set) var isLoading = false
    @Published var searchText = ""
    @Published var filter: Filter = .all
    @Published var errorMessage: String?

    private let sessionStore: SessionStore
    private var hasLoaded = false

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    var filteredProviders: [AdminProvider] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return providers.filter { provider in
            let matchesState: Bool
            switch filter {
            case .all: matchesState = true
            case .enabled: matchesState = provider.isEnabled
            case .disabled: matchesState = !provider.isEnabled
            }
            return matchesState && (query.isEmpty || provider.searchableText.contains(query))
        }
    }

    var enabledCount: Int { providers.filter(\.isEnabled).count }
    var providerTypes: [String] { Array(Set(providers.compactMap(\.providerType))).sorted() }
    var todayCost: Double { providers.compactMap(\.todayTotalCostUsd).reduce(0, +) }
    var todayCalls: Int { providers.compactMap(\.todayCallCount).reduce(0, +) }

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
            errorMessage = "Provider management is available for admin accounts."
            return
        }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            providers = try await client.getAdminProviders().sorted { left, right in
                if left.isEnabled != right.isEnabled { return left.isEnabled && !right.isEnabled }
                if (left.priority ?? Int.max) != (right.priority ?? Int.max) { return (left.priority ?? Int.max) < (right.priority ?? Int.max) }
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }
        } catch {
            if sessionStore.handleAPIError(error) { return }
            errorMessage = APIError.userMessage(for: error)
        }
    }
}
