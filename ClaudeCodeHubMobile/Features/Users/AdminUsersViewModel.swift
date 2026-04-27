import Foundation

@MainActor
final class AdminUsersViewModel: ObservableObject {
    @Published private(set) var users: [AdminUser] = []
    @Published private(set) var isLoading = false
    @Published var searchText = ""
    @Published var showsDisabledOnly = false
    @Published var errorMessage: String?

    private let sessionStore: SessionStore
    private var hasLoaded = false

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    var filteredUsers: [AdminUser] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return users.filter { user in
            (!showsDisabledOnly || !user.isEnabled) && (query.isEmpty || user.searchableText.contains(query))
        }
    }

    var totalKeyCount: Int { users.reduce(0) { $0 + $1.keys.count } }
    var disabledUserCount: Int { users.filter { !$0.isEnabled }.count }

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
            errorMessage = "User management is available for admin accounts."
            return
        }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            users = try await client.getAdminUsers().sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            if sessionStore.handleAPIError(error) { return }
            errorMessage = APIError.userMessage(for: error)
        }
    }
}
