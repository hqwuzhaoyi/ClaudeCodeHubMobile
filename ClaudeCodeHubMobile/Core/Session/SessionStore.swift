import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var baseURL: URL?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isBootstrapping = true
    @Published private(set) var lastLoginResponse: LoginResponse?
    @Published var sessionErrorMessage: String?

    private let defaults: UserDefaults
    private let cookieStorage: HTTPCookieStorage
    private var apiClient: APIClient?

    private enum DefaultsKey {
        static let baseURL = "ClaudeCodeHubMobile.baseURL"
        static let isAuthenticated = "ClaudeCodeHubMobile.isAuthenticated"
        static let loginType = "ClaudeCodeHubMobile.loginType"
    }

    var client: APIClient? { apiClient }
    var serverDisplayName: String { baseURL?.absoluteString ?? "No server" }
    var isAdmin: Bool { lastLoginResponse?.isAdmin == true }

    init(defaults: UserDefaults = .standard, cookieStorage: HTTPCookieStorage = .shared) {
        self.defaults = defaults
        self.cookieStorage = cookieStorage
    }

    func bootstrap() async {
        guard isBootstrapping else { return }
        defer { isBootstrapping = false }

        guard let storedURLString = defaults.string(forKey: DefaultsKey.baseURL),
              let storedURL = URL(string: storedURLString),
              defaults.bool(forKey: DefaultsKey.isAuthenticated) else {
            return
        }

        guard hasSessionCookies(for: storedURL) else {
            resetSession(shouldClearCookies: false, message: nil)
            return
        }

        let client = APIClient(baseURL: storedURL)
        do {
            try await client.validateSession()
            baseURL = storedURL
            apiClient = client
            isAuthenticated = true
            if let loginType = defaults.string(forKey: DefaultsKey.loginType) {
                lastLoginResponse = LoginResponse(success: true, loginType: loginType)
            }
        } catch {
            resetSession(shouldClearCookies: true, message: APIError.sessionExpired.message, baseURLForCookieClear: storedURL)
        }
    }

    func clearSessionMessage() {
        sessionErrorMessage = nil
    }

    func signIn(baseURLString: String, accessKey: String) async throws {
        sessionErrorMessage = nil
        let normalizedURL = try Self.normalizedURL(from: baseURLString)
        let client = APIClient(baseURL: normalizedURL)
        let response = try await client.login(accessKey: accessKey)
        if response.success == false {
            throw APIError.authenticationFailed
        }
        do {
            try await client.validateSession()
        } catch {
            clearCookies(for: normalizedURL)
            throw APIError.authenticationFailed
        }

        baseURL = normalizedURL
        apiClient = client
        isAuthenticated = true
        lastLoginResponse = response
        sessionErrorMessage = nil
        defaults.set(normalizedURL.absoluteString, forKey: DefaultsKey.baseURL)
        defaults.set(true, forKey: DefaultsKey.isAuthenticated)
        if let loginType = response.loginType {
            defaults.set(loginType, forKey: DefaultsKey.loginType)
        } else {
            defaults.removeObject(forKey: DefaultsKey.loginType)
        }
    }

    func signOut() {
        resetSession(shouldClearCookies: true, message: nil)
    }

    func handleAPIError(_ error: Error) -> Bool {
        guard let apiError = error as? APIError, apiError.isSessionExpired else { return false }
        resetSession(shouldClearCookies: true, message: APIError.sessionExpired.message)
        return true
    }

    private func resetSession(shouldClearCookies: Bool, message: String?, baseURLForCookieClear: URL? = nil) {
        let cookieURL = baseURLForCookieClear ?? baseURL
        if shouldClearCookies, let cookieURL {
            clearCookies(for: cookieURL)
        }
        baseURL = nil
        apiClient = nil
        isAuthenticated = false
        lastLoginResponse = nil
        sessionErrorMessage = message
        defaults.removeObject(forKey: DefaultsKey.baseURL)
        defaults.removeObject(forKey: DefaultsKey.isAuthenticated)
        defaults.removeObject(forKey: DefaultsKey.loginType)
    }

    private func hasSessionCookies(for baseURL: URL) -> Bool {
        guard let host = baseURL.host else { return false }
        return cookieStorage.cookies?.contains { cookie in
            guard cookie.expiresDate.map({ $0 > Date() }) ?? true else { return false }
            let domain = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            return host == domain || host.hasSuffix(".\(domain)") || domain.hasSuffix(".\(host)")
        } ?? false
    }

    private func clearCookies(for baseURL: URL) {
        guard let host = baseURL.host else { return }
        cookieStorage.cookies?.forEach { cookie in
            let domain = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if host == domain || host.hasSuffix(".\(domain)") || domain.hasSuffix(".\(host)") {
                cookieStorage.deleteCookie(cookie)
            }
        }
    }

    static func normalizedURL(from rawValue: String) throws -> URL {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host?.isEmpty == false else {
            throw APIError.invalidBaseURL
        }
        components.scheme = scheme
        components.query = nil
        components.fragment = nil
        guard let url = components.url else { throw APIError.invalidBaseURL }
        return url
    }
}

extension SessionStore {
    static var previewSignedOut: SessionStore {
        let store = SessionStore(defaults: .preview)
        store.isBootstrapping = false
        return store
    }

    static var previewSignedIn: SessionStore {
        let store = SessionStore(defaults: .preview)
        store.isBootstrapping = false
        store.baseURL = URL(string: "https://hub.example.com")
        store.apiClient = store.baseURL.map { APIClient(baseURL: $0) }
        store.isAuthenticated = true
        store.lastLoginResponse = LoginResponse(user: UserContext(name: "Preview User", role: "admin"), message: nil, success: true, loginType: "admin")
        return store
    }
}

private extension UserDefaults {
    static var preview: UserDefaults {
        UserDefaults(suiteName: "ClaudeCodeHubMobile.preview") ?? .standard
    }
}
