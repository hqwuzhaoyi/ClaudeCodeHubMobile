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
    @Published private(set) var healthStatuses: [ProviderHealthStatus] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isWriting = false
    @Published private(set) var writeMessage: String?
    @Published var searchText = ""
    @Published var filter: Filter = .all
    @Published var errorMessage: String?
    @Published var pendingWrite: AdminProviderWriteConfirmation?

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
    var openCircuitProviderIds: Set<Int> { Set(healthStatuses.filter(\.isCircuitOpen).map(\.providerId)) }
    var circuitStatusByProviderId: [Int: ProviderHealthStatus] {
        Dictionary(uniqueKeysWithValues: healthStatuses.map { ($0.providerId, $0) })
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
            async let providersRequest = client.getAdminProviders()
            async let healthRequest = client.getProvidersHealthStatus()
            healthStatuses = (try? await healthRequest) ?? []
            let loadedProviders = try await providersRequest
            providers = loadedProviders.sorted { left, right in
                if left.isEnabled != right.isEnabled { return left.isEnabled && !right.isEnabled }
                if (left.priority ?? Int.max) != (right.priority ?? Int.max) { return (left.priority ?? Int.max) < (right.priority ?? Int.max) }
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }
        } catch {
            if sessionStore.handleAPIError(error) { return }
            errorMessage = APIError.userMessage(for: error)
        }
    }

    func prepareCircuitReset(provider: AdminProvider, health: ProviderHealthStatus) {
        pendingWrite = AdminProviderWriteConfirmation(
            providerId: provider.id,
            providerName: provider.name,
            title: "Reset circuit for \(provider.name)?",
            message: "Only reset after the upstream provider has recovered. The app will refresh health status after the write.",
            before: "\(health.displayState), \(health.failureCount) failures",
            after: "Closed circuit pending server acceptance",
            confirmTitle: "Reset Circuit"
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
            errorMessage = "Provider writes are available for admin accounts."
            pendingWrite = nil
            return
        }

        isWriting = true
        errorMessage = nil
        writeMessage = nil
        defer { isWriting = false }

        do {
            let result = try await client.resetProviderCircuit(providerId: confirmation.providerId)
            guard result.success else {
                errorMessage = result.message ?? "Provider circuit reset was rejected by the server."
                pendingWrite = nil
                return
            }

            writeMessage = result.message ?? "Circuit reset requested for \(confirmation.providerName)."
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

struct AdminProviderWriteConfirmation: Identifiable, Equatable {
    let id = UUID()
    let providerId: Int
    let providerName: String
    let title: String
    let message: String
    let before: String
    let after: String
    let confirmTitle: String
}
