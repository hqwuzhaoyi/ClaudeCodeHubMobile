import Foundation

@MainActor
final class AdminUsersViewModel: ObservableObject {
    @Published private(set) var users: [AdminUser] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isWriting = false
    @Published private(set) var writeMessage: String?
    @Published var searchText = ""
    @Published var showsDisabledOnly = false
    @Published var errorMessage: String?
    @Published var pendingWrite: AdminUserWriteConfirmation?

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

    func prepareUserToggle(_ user: AdminUser) {
        let targetEnabled = !user.isEnabled
        pendingWrite = AdminUserWriteConfirmation(
            target: .user(id: user.id, name: user.name, targetEnabled: targetEnabled),
            title: "\(targetEnabled ? "Enable" : "Disable") \(user.name)?",
            message: "This writes to the admin user action after confirmation and then refreshes the user list.",
            before: user.isEnabled ? "Enabled" : "Disabled",
            after: targetEnabled ? "Enabled" : "Disabled",
            confirmTitle: targetEnabled ? "Enable User" : "Disable User",
            isDestructive: !targetEnabled
        )
    }

    func prepareKeyToggle(_ key: AdminAPIKey, owner: AdminUser) {
        let targetEnabled = !key.isEnabled
        pendingWrite = AdminUserWriteConfirmation(
            target: .key(id: key.id, name: key.name, ownerName: owner.name, targetEnabled: targetEnabled),
            title: "\(targetEnabled ? "Enable" : "Disable") key \(key.name)?",
            message: "This writes to the admin key action for \(owner.name) after confirmation and then refreshes the user list.",
            before: key.isEnabled ? "Enabled" : "Disabled",
            after: targetEnabled ? "Enabled" : "Disabled",
            confirmTitle: targetEnabled ? "Enable Key" : "Disable Key",
            isDestructive: !targetEnabled
        )
    }

    func cancelPendingWrite() {
        pendingWrite = nil
    }

    func commitPendingWrite() async {
        guard let confirmation = pendingWrite else { return }
        guard let client = sessionStore.client else {
            errorMessage = APIError.missingSession.message
            pendingWrite = nil
            return
        }
        guard sessionStore.isAdmin else {
            errorMessage = "User management writes are available for admin accounts."
            pendingWrite = nil
            return
        }

        isWriting = true
        errorMessage = nil
        writeMessage = nil
        defer { isWriting = false }

        do {
            let result: AdminWriteResult
            switch confirmation.target {
            case .user(let id, _, let targetEnabled):
                result = try await client.setAdminUserEnabled(userId: id, isEnabled: targetEnabled)
            case .key(let id, _, _, let targetEnabled):
                result = try await client.setAdminKeyEnabled(keyId: id, isEnabled: targetEnabled)
            }

            guard result.success else {
                errorMessage = result.message ?? "Admin write was rejected by the server."
                pendingWrite = nil
                return
            }

            writeMessage = result.message ?? "\(confirmation.after) update completed."
            pendingWrite = nil
            hasLoaded = false
            await refresh()
        } catch {
            if sessionStore.handleAPIError(error) { return }
            errorMessage = APIError.userMessage(for: error)
            pendingWrite = nil
        }
    }
}

struct AdminUserWriteConfirmation: Identifiable, Equatable {
    enum Target: Equatable {
        case user(id: Int, name: String, targetEnabled: Bool)
        case key(id: Int, name: String, ownerName: String, targetEnabled: Bool)
    }

    let id = UUID()
    let target: Target
    let title: String
    let message: String
    let before: String
    let after: String
    let confirmTitle: String
    let isDestructive: Bool
}
