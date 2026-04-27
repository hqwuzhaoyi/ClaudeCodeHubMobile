import Foundation

final class APIClient {
    let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL, session: URLSession? = nil) {
        self.baseURL = baseURL.normalizedBaseURL
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.httpCookieStorage = .shared
            configuration.httpShouldSetCookies = true
            configuration.httpCookieAcceptPolicy = .always
            configuration.timeoutIntervalForRequest = 30
            self.session = URLSession(configuration: configuration)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self), let date = AppFormatters.parseDate(string) {
                return date
            }
            if let seconds = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: seconds > 9_999_999_999 ? seconds / 1_000 : seconds)
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported date value")
        }
        self.decoder = decoder
        self.encoder = JSONEncoder()
    }

    func login(accessKey: String) async throws -> LoginResponse {
        let data = try await postData("/api/auth/login", body: LoginRequest(key: accessKey), mapsUnauthorizedToSessionExpired: false)
        guard !data.isEmpty else { return LoginResponse(message: "Signed in", success: true) }
        do {
            return try decoder.decode(FlexibleEnvelope<LoginResponse>.self, from: data).value
        } catch {
            throw APIError.decoding(error)
        }
    }

    func getQuota() async throws -> QuotaSummary {
        let response: FlexibleEnvelope<QuotaSummary> = try await post("/api/actions/my-usage/getMyQuota", body: EmptyBody())
        return response.value
    }

    func getStatsSummary() async throws -> StatsSummary {
        let response: FlexibleEnvelope<StatsSummary> = try await post("/api/actions/my-usage/getMyStatsSummary", body: EmptyBody())
        return response.value
    }

    func getUsageLogs(limit: Int = 100, offset: Int = 0, cursor: UsageLogsCursor? = nil) async throws -> UsageLogsResponse {
        let response: FlexibleEnvelope<UsageLogsResponse> = try await post(
            "/api/actions/my-usage/getMyUsageLogsBatch",
            body: UsageLogsRequest(limit: limit, offset: offset, cursor: cursor)
        )
        return response.value
    }

    func getDashboardUsageLogs(limit: Int = 100, offset: Int = 0, filter: DashboardUsageLogsFilter? = nil) async throws -> UsageLogsResponse {
        let pageSize = max(1, min(limit, 100))
        let page = max(1, (offset / pageSize) + 1)
        let response: FlexibleEnvelope<UsageLogsResponse> = try await post(
            "/api/actions/usage-logs/getUsageLogs",
            body: DashboardUsageLogsRequest(pageSize: pageSize, page: page, filter: filter)
        )
        return response.value
    }

    func getActiveSessions() async throws -> [ActiveSession] {
        let response: FlexibleEnvelope<[ActiveSession]> = try await post(
            "/api/actions/active-sessions/getActiveSessions",
            body: EmptyBody()
        )
        return response.value
    }

    func getDashboardOverview() async throws -> StatsSummary {
        let response: FlexibleEnvelope<StatsSummary> = try await post("/api/actions/overview/getOverviewData", body: EmptyBody())
        return response.value
    }

    func getDashboardLeaderboard(
        scope: DashboardLeaderboardScope,
        period: DashboardLeaderboardPeriod = .daily
    ) async throws -> [DashboardLeaderboardEntry] {
        var query = "period=\(period.rawValue)&scope=\(scope.rawValue)"
        if scope == .provider {
            query += "&includeModelStats=1"
        }
        return try await get("/api/leaderboard?\(query)")
    }

    func getAdminUsers() async throws -> [AdminUser] {
        let response: FlexibleEnvelope<[AdminUser]> = try await post(
            "/api/actions/users/getUsers",
            body: EmptyBody()
        )
        return response.value
    }

    func getAdminProviders() async throws -> [AdminProvider] {
        let response: FlexibleEnvelope<[AdminProvider]> = try await post(
            "/api/actions/providers/getProviders",
            body: EmptyBody()
        )
        return response.value
    }

    func validateSession() async throws {
        _ = try await postData("/api/actions/my-usage/getMyQuota", body: EmptyBody())
    }

    func getAvailableModels() async throws -> [String] {
        let response: FlexibleEnvelope<StringListResponse> = try await post("/api/actions/my-usage/getMyAvailableModels", body: EmptyBody())
        return response.value.values
    }

    func getAvailableEndpoints() async throws -> [String] {
        let response: FlexibleEnvelope<StringListResponse> = try await post("/api/actions/my-usage/getMyAvailableEndpoints", body: EmptyBody())
        return response.value.values
    }

    func getDashboardAvailableModels() async throws -> [String] {
        let response: FlexibleEnvelope<StringListResponse> = try await post("/api/actions/usage-logs/getModelList", body: EmptyBody())
        return response.value.values
    }

    func getServerTimeZone() async throws -> String? {
        let response: ServerTimeZoneResponse = try await get("/api/system-settings")
        AppFormatters.serverTimeZone = AppFormatters.resolvedTimeZone(response.identifier)
        return response.identifier
    }

    private func post<Response: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> Response {
        let data = try await postData(path, body: body)
        return try decodeResponse(data)
    }

    private func get<Response: Decodable>(_ path: String) async throws -> Response {
        let data = try await requestData(path, method: "GET", body: Optional<EmptyBody>.none)
        return try decodeResponse(data)
    }

    private func decodeResponse<Response: Decodable>(_ data: Data) throws -> Response {
        if data.isEmpty, Response.self == EmptyResponse.self, let empty = EmptyResponse() as? Response {
            return empty
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func postData<Body: Encodable>(_ path: String, body: Body, mapsUnauthorizedToSessionExpired: Bool = true) async throws -> Data {
        try await requestData(path, method: "POST", body: body, mapsUnauthorizedToSessionExpired: mapsUnauthorizedToSessionExpired)
    }

    private func requestData<Body: Encodable>(_ path: String, method: String, body: Body?, mapsUnauthorizedToSessionExpired: Bool = true) async throws -> Data {
        let url = baseURL.appendingActionPath(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Claude Code Hub's CSRF guard accepts same-origin browser fetches. Native URLSession
        // requests do not automatically include Fetch Metadata headers, so mark requests as
        // first-party to match the user-configured server origin after the user provides a key.
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                if !mapsUnauthorizedToSessionExpired, httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw APIError.authenticationFailed
                }
                throw APIError.httpStatus(httpResponse.statusCode, body: data)
            }
            return data
        } catch {
            throw APIError.network(error)
        }
    }
}

private struct LoginRequest: Encodable {
    let key: String
}

private struct UsageLogsRequest: Encodable {
    let limit: Int
    let offset: Int
    let cursor: UsageLogsCursor?
}

private struct DashboardUsageLogsRequest: Encodable {
    let pageSize: Int
    let page: Int
    let search: String?
    let userId: Int?
    let providerId: Int?
    let sessionId: String?

    init(pageSize: Int, page: Int, filter: DashboardUsageLogsFilter? = nil) {
        self.pageSize = pageSize
        self.page = page
        self.search = filter?.search
        self.userId = filter?.userId
        self.providerId = filter?.providerId
        self.sessionId = filter?.sessionId
    }
}

private extension URL {
    var normalizedBaseURL: URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        var url = components?.url ?? self
        if url.path == "/" {
            url.deleteLastPathComponent()
        }
        return url
    }

    func appendingActionPath(_ path: String) -> URL {
        var cleanPath = path
        while cleanPath.hasPrefix("/") {
            cleanPath.removeFirst()
        }
        let pathParts = cleanPath.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        cleanPath = String(pathParts.first ?? "")

        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        let basePath = components?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        let joinedPath = ([basePath, cleanPath].filter { !$0.isEmpty }).joined(separator: "/")
        components?.path = "/" + joinedPath
        if pathParts.count > 1 {
            components?.percentEncodedQuery = String(pathParts[1])
        }
        return components?.url ?? appendingPathComponent(cleanPath)
    }
}
