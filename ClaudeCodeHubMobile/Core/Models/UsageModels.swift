import Foundation

struct LoginResponse: Decodable, Equatable {
    let user: UserContext?
    let message: String?
    let success: Bool?
    let loginType: String?

    var isAdmin: Bool { loginType == "admin" || user?.role == "admin" }

    init(user: UserContext? = nil, message: String? = nil, success: Bool? = nil, loginType: String? = nil) {
        self.user = user
        self.message = message
        self.success = success
        self.loginType = loginType
    }

    init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: DynamicCodingKey.self)
        user = try? container?.decode(UserContext.self, forKey: DynamicCodingKey(stringValue: "user")!)
        message = container?.decodeString(forPossibleKeys: ["message", "msg", "error"])
        success = container?.decodeBool(forPossibleKeys: ["success", "ok", "authenticated"])
        loginType = container?.decodeString(forPossibleKeys: ["loginType", "type", "role"])
    }
}

struct UserContext: Decodable, Equatable {
    let id: String?
    let name: String?
    let email: String?
    let keyName: String?
    let role: String?

    var displayName: String {
        name ?? email ?? keyName ?? id ?? "Signed-in user"
    }

    init(id: String? = nil, name: String? = nil, email: String? = nil, keyName: String? = nil, role: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.keyName = keyName
        self.role = role
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = container.decodeString(forPossibleKeys: ["id", "userId", "uid"])
        name = container.decodeString(forPossibleKeys: ["name", "displayName", "username"])
        email = container.decodeString(forPossibleKeys: ["email", "mail"])
        keyName = container.decodeString(forPossibleKeys: ["keyName", "accessKeyName", "tokenName"])
        role = container.decodeString(forPossibleKeys: ["role", "userRole"])
    }
}

struct QuotaSummary: Decodable, Equatable {
    let status: String?
    let quota: Double?
    let remaining: Double?
    let used: Double?
    let expiresAt: Date?

    var isActive: Bool? {
        guard let status else { return nil }
        let normalized = status.lowercased()
        if ["active", "enabled", "valid", "ok"].contains(normalized) { return true }
        if ["inactive", "disabled", "expired", "blocked"].contains(normalized) { return false }
        return nil
    }

    init(status: String? = nil, quota: Double? = nil, remaining: Double? = nil, used: Double? = nil, expiresAt: Date? = nil) {
        self.status = status
        self.quota = quota
        self.remaining = remaining
        self.used = used
        self.expiresAt = expiresAt
    }

    init(from decoder: Decoder) throws {
        try self.init(from: decoder, serverTimeZone: nil)
    }

    init(from decoder: Decoder, serverTimeZone: TimeZone?) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        let keyIsEnabled = container.decodeBool(forPossibleKeys: ["keyIsEnabled"])
        let userIsEnabled = container.decodeBool(forPossibleKeys: ["userIsEnabled"])
        if let explicitStatus = container.decodeString(forPossibleKeys: ["status", "state", "accountStatus"]) {
            status = explicitStatus
        } else if keyIsEnabled == false || userIsEnabled == false {
            status = "disabled"
        } else if keyIsEnabled == true || userIsEnabled == true {
            status = "active"
        } else {
            status = nil
        }

        quota = container.decodeDouble(forPossibleKeys: [
            "quota", "totalQuota", "limit", "balance", "amount",
            "keyLimitDailyUsd", "userLimitDailyUsd", "keyLimitTotalUsd", "userLimitTotalUsd"
        ])
        used = container.decodeDouble(forPossibleKeys: [
            "used", "usedQuota", "consumed", "usage", "spent",
            "keyCurrentDailyUsd", "userCurrentDailyUsd", "keyCurrentTotalUsd", "userCurrentTotalUsd"
        ])
        if let explicitRemaining = container.decodeDouble(forPossibleKeys: ["remaining", "remainingQuota", "available", "left", "balanceRemaining"]) {
            remaining = explicitRemaining
        } else if let quota, let used {
            remaining = max(0, quota - used)
        } else {
            remaining = nil
        }
        expiresAt = container.decodeDate(forPossibleKeys: ["expiresAt", "expireAt", "expiredAt", "expiration", "validUntil", "endTime", "keyExpiresAt", "userExpiresAt"], timeZone: serverTimeZone)
    }
}

struct StatsSummary: Decodable, Equatable {
    let totalRequests: Int?
    let totalCost: Double?
    let totalTokens: Int?
    let rangeLabel: String?
    let concurrentSessions: Int?
    let avgResponseTimeMs: Int?
    let todayErrorRate: Double?
    let yesterdaySamePeriodRequests: Int?
    let yesterdaySamePeriodCost: Double?
    let yesterdaySamePeriodAvgResponseTimeMs: Int?
    let recentMinuteRequests: Int?
    let topModels: [BreakdownItem]
    let topEndpoints: [BreakdownItem]

    init(
        totalRequests: Int? = nil,
        totalCost: Double? = nil,
        totalTokens: Int? = nil,
        rangeLabel: String? = nil,
        concurrentSessions: Int? = nil,
        avgResponseTimeMs: Int? = nil,
        todayErrorRate: Double? = nil,
        yesterdaySamePeriodRequests: Int? = nil,
        yesterdaySamePeriodCost: Double? = nil,
        yesterdaySamePeriodAvgResponseTimeMs: Int? = nil,
        recentMinuteRequests: Int? = nil,
        topModels: [BreakdownItem] = [],
        topEndpoints: [BreakdownItem] = []
    ) {
        self.totalRequests = totalRequests
        self.totalCost = totalCost
        self.totalTokens = totalTokens
        self.rangeLabel = rangeLabel
        self.concurrentSessions = concurrentSessions
        self.avgResponseTimeMs = avgResponseTimeMs
        self.todayErrorRate = todayErrorRate
        self.yesterdaySamePeriodRequests = yesterdaySamePeriodRequests
        self.yesterdaySamePeriodCost = yesterdaySamePeriodCost
        self.yesterdaySamePeriodAvgResponseTimeMs = yesterdaySamePeriodAvgResponseTimeMs
        self.recentMinuteRequests = recentMinuteRequests
        self.topModels = topModels
        self.topEndpoints = topEndpoints
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        totalRequests = container.decodeInt(forPossibleKeys: ["totalRequests", "requests", "requestCount", "count", "todayRequests"])
        totalCost = container.decodeDouble(forPossibleKeys: ["totalCost", "cost", "amount", "spent", "todayCost"])
        totalTokens = container.decodeInt(forPossibleKeys: ["totalTokens", "tokens", "tokenCount"])
        rangeLabel = container.decodeString(forPossibleKeys: ["range", "rangeLabel", "period", "window"]) ?? (container.contains(DynamicCodingKey(stringValue: "todayRequests")!) ? "Today" : nil)
        concurrentSessions = container.decodeInt(forPossibleKeys: ["concurrentSessions", "concurrent", "activeSessions"])
        avgResponseTimeMs = container.decodeInt(forPossibleKeys: ["avgResponseTime", "avgResponseTimeMs", "averageResponseTimeMs"])
        todayErrorRate = container.decodeDouble(forPossibleKeys: ["todayErrorRate", "errorRate"])
        yesterdaySamePeriodRequests = container.decodeInt(forPossibleKeys: ["yesterdaySamePeriodRequests", "previousRequests"])
        yesterdaySamePeriodCost = container.decodeDouble(forPossibleKeys: ["yesterdaySamePeriodCost", "previousCost"])
        yesterdaySamePeriodAvgResponseTimeMs = container.decodeInt(forPossibleKeys: ["yesterdaySamePeriodAvgResponseTime", "previousAvgResponseTime"])
        recentMinuteRequests = container.decodeInt(forPossibleKeys: ["recentMinuteRequests", "rpm", "requestsPerMinute"])
        topModels = StatsSummary.decodeBreakdown(from: container, keys: ["topModels", "models", "modelBreakdown", "byModel", "keyModelBreakdown", "userModelBreakdown"])
        topEndpoints = StatsSummary.decodeBreakdown(from: container, keys: ["topEndpoints", "endpoints", "endpointBreakdown", "byEndpoint"])
    }

    private static func decodeBreakdown(from container: KeyedDecodingContainer<DynamicCodingKey>, keys: [String]) -> [BreakdownItem] {
        for key in keys {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            if let items = try? container.decode([BreakdownItem].self, forKey: codingKey) {
                return items
            }
            if let dictionary = try? container.decode([String: Double].self, forKey: codingKey) {
                return dictionary.map { BreakdownItem(label: $0.key, value: $0.value, count: nil) }
                    .sorted { ($0.value ?? 0) > ($1.value ?? 0) }
            }
            if let dictionary = try? container.decode([String: Int].self, forKey: codingKey) {
                return dictionary.map { BreakdownItem(label: $0.key, value: nil, count: $0.value) }
                    .sorted { ($0.count ?? 0) > ($1.count ?? 0) }
            }
        }
        return []
    }
}

struct BreakdownItem: Decodable, Equatable, Identifiable {
    var id: String { label }
    let label: String
    let value: Double?
    let count: Int?

    init(label: String, value: Double? = nil, count: Int? = nil) {
        self.label = label
        self.value = value
        self.count = count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        label = container.decodeString(forPossibleKeys: ["label", "name", "model", "endpoint", "key", "path"]) ?? "Unknown"
        value = container.decodeDouble(forPossibleKeys: ["value", "cost", "amount", "usage", "costUsd"])
        count = container.decodeInt(forPossibleKeys: ["count", "requests", "requestCount", "total", "calls"])
    }
}

struct UsageLogsCursor: Codable, Equatable {
    let createdAt: String?
    let id: Int?
    let rawValue: String?

    init(createdAt: String? = nil, id: Int? = nil, rawValue: String? = nil) {
        self.createdAt = createdAt
        self.id = id
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        if let raw = try? String(from: decoder) {
            createdAt = nil
            id = nil
            rawValue = raw
            return
        }
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        createdAt = container.decodeString(forPossibleKeys: ["createdAt", "created_at", "timestamp", "time"])
        id = container.decodeInt(forPossibleKeys: ["id", "logId"])
        rawValue = nil
    }

    func encode(to encoder: Encoder) throws {
        if let rawValue, createdAt == nil, id == nil {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
            return
        }
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        try container.encodeIfPresent(createdAt, forKey: DynamicCodingKey(stringValue: "createdAt")!)
        try container.encodeIfPresent(id, forKey: DynamicCodingKey(stringValue: "id")!)
    }
}

struct UsageLogsResponse: Decodable, Equatable {
    let records: [UsageLog]
    let total: Int?
    let nextCursor: UsageLogsCursor?
    let hasMore: Bool?

    init(records: [UsageLog] = [], total: Int? = nil, nextCursor: UsageLogsCursor? = nil, hasMore: Bool? = nil) {
        self.records = records
        self.total = total
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }

    init(from decoder: Decoder) throws {
        if let records = try? [UsageLog](from: decoder) {
            self.records = records
            self.total = records.count
            self.nextCursor = nil
            self.hasMore = nil
            return
        }

        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var decodedRecords: [UsageLog] = []
        for key in ["logs", "records", "items", "rows", "data", "list"] {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            if let records = try? container.decode([UsageLog].self, forKey: codingKey) {
                decodedRecords = records
                break
            }
        }
        records = decodedRecords
        total = container.decodeInt(forPossibleKeys: ["total", "totalCount", "count"])
        nextCursor = container.decodeCursor(forPossibleKeys: ["nextCursor", "cursor", "next", "nextPageToken"])
        hasMore = container.decodeBool(forPossibleKeys: ["hasMore", "hasNext", "more", "canLoadMore"])
    }
}

struct RecentRecordHighlighter: Equatable {
    private var hasSnapshot = false
    private var knownIDs: Set<String> = []
    private(set) var highlightedIDs: Set<String> = []

    mutating func update(with currentIDs: [String]) -> Set<String> {
        let current = Set(currentIDs)
        defer {
            knownIDs.formUnion(current)
            hasSnapshot = true
        }
        guard hasSnapshot else { return [] }
        let inserted = current.subtracting(knownIDs)
        highlightedIDs.formUnion(inserted)
        return inserted
    }

    mutating func clear(_ id: String) {
        highlightedIDs.remove(id)
    }

    func isHighlighted(_ id: String) -> Bool {
        highlightedIDs.contains(id)
    }
}

struct UsageLog: Decodable, Equatable, Identifiable {
    let id: String
    let timestamp: Date?
    let sessionId: String?
    let requestSequence: Int?
    let userName: String?
    let keyName: String?
    let providerName: String?
    let originalModel: String?
    let model: String?
    let endpoint: String?
    let status: String?
    let statusCode: Int?
    let cost: Double?
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?
    let totalTokens: Int?
    let durationMs: Int?
    let ttfbMs: Int?
    let errorMessage: String?

    var isRequesting: Bool {
        status == nil && statusCode == nil && sessionId != nil && (requestSequence != nil || durationMs != nil || ttfbMs != nil)
    }

    var displayStatus: String {
        if let status, !status.isEmpty { return status }
        if let statusCode { return (200..<400).contains(statusCode) ? "success" : "failed" }
        if isRequesting { return "requesting" }
        return "unknown"
    }

    var statusCategory: String {
        if let statusCode { return (200..<400).contains(statusCode) ? "success" : "failed" }
        if isRequesting { return "requesting" }
        guard let status else { return "unknown" }
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return "unknown" }
        if ["success", "succeeded", "ok", "complete", "completed", "done"].contains(normalized) || normalized.hasPrefix("2") {
            return "success"
        }
        if ["failed", "failure", "error", "timeout", "timed_out", "denied", "rejected", "blocked", "unauthorized", "forbidden", "invalid", "cancelled", "canceled"].contains(normalized) {
            return "failed"
        }
        if normalized.contains("error") || normalized.contains("fail") || normalized.contains("timeout") || normalized.contains("denied") {
            return "failed"
        }
        return "unknown"
    }

    init(
        id: String = UUID().uuidString,
        timestamp: Date? = nil,
        sessionId: String? = nil,
        requestSequence: Int? = nil,
        userName: String? = nil,
        keyName: String? = nil,
        providerName: String? = nil,
        originalModel: String? = nil,
        model: String? = nil,
        endpoint: String? = nil,
        status: String? = nil,
        statusCode: Int? = nil,
        cost: Double? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        cacheCreationInputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil,
        totalTokens: Int? = nil,
        durationMs: Int? = nil,
        ttfbMs: Int? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.requestSequence = requestSequence
        self.userName = userName
        self.keyName = keyName
        self.providerName = providerName
        self.originalModel = originalModel
        self.model = model
        self.endpoint = endpoint
        self.status = status
        self.statusCode = statusCode
        self.cost = cost
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.totalTokens = totalTokens
        self.durationMs = durationMs
        self.ttfbMs = ttfbMs
        self.errorMessage = errorMessage
    }

    init(from decoder: Decoder) throws {
        try self.init(from: decoder, serverTimeZone: nil)
    }

    init(from decoder: Decoder, serverTimeZone: TimeZone?) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = container.decodeString(forPossibleKeys: ["id", "requestId", "logId", "uuid"]) ?? UUID().uuidString
        timestamp = container.decodeDate(forPossibleKeys: ["timestamp", "createdAt", "created_at", "time", "date"], timeZone: serverTimeZone)
        sessionId = container.decodeString(forPossibleKeys: ["sessionId", "session_id"])
        requestSequence = container.decodeInt(forPossibleKeys: ["requestSequence", "sequence", "seq"])
        userName = container.decodeString(forPossibleKeys: ["userName", "username", "user"])
        keyName = container.decodeString(forPossibleKeys: ["keyName", "accessKeyName", "tokenName"])
        providerName = container.decodeString(forPossibleKeys: ["providerName", "provider"])
        originalModel = container.decodeString(forPossibleKeys: ["originalModel", "requestedModel"])
        model = container.decodeString(forPossibleKeys: ["model", "modelName", "model_name"])
        endpoint = container.decodeString(forPossibleKeys: ["endpoint", "path", "route", "api", "url", "apiType"])
        status = container.decodeString(forPossibleKeys: ["status", "state", "result"])
        statusCode = container.decodeInt(forPossibleKeys: ["statusCode", "code", "httpStatus"])
        cost = container.decodeDouble(forPossibleKeys: ["cost", "amount", "price", "totalCost", "costUsd"])
        inputTokens = container.decodeInt(forPossibleKeys: ["inputTokens", "promptTokens", "prompt_tokens"])
        outputTokens = container.decodeInt(forPossibleKeys: ["outputTokens", "completionTokens", "completion_tokens"])
        cacheCreationInputTokens = container.decodeInt(forPossibleKeys: ["cacheCreationInputTokens", "cacheWriteTokens", "cache_creation_input_tokens"])
        cacheReadInputTokens = container.decodeInt(forPossibleKeys: ["cacheReadInputTokens", "cacheReadTokens", "cache_read_input_tokens"])
        totalTokens = container.decodeInt(forPossibleKeys: ["totalTokens", "tokens", "tokenCount"])
        durationMs = container.decodeInt(forPossibleKeys: ["durationMs", "duration", "latencyMs"])
        ttfbMs = container.decodeInt(forPossibleKeys: ["ttfbMs", "timeToFirstByteMs"])
        errorMessage = container.decodeString(forPossibleKeys: ["errorMessage", "error", "message"])
    }
}

struct ActiveSession: Decodable, Equatable, Identifiable {
    var id: String { sessionId }

    let sessionId: String
    let userName: String?
    let userId: Int?
    let keyId: Int?
    let keyName: String?
    let providerId: Int?
    let providerName: String?
    let model: String?
    let apiType: String?
    let startTime: Date?
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?
    let totalTokens: Int?
    let cost: Double?
    let status: String?
    let durationMs: Int?
    let requestCount: Int?
    let concurrentCount: Int?

    var isLive: Bool {
        if let concurrentCount, concurrentCount > 0 { return true }
        let normalized = status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return ["in_progress", "running", "active", "streaming", "pending"].contains(normalized)
    }

    var displayStatus: String {
        guard let status, !status.isEmpty else { return isLive ? "active" : "unknown" }
        return status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        sessionId = container.decodeString(forPossibleKeys: ["sessionId", "session_id", "id"]) ?? UUID().uuidString
        userName = container.decodeString(forPossibleKeys: ["userName", "username", "user"])
        userId = container.decodeInt(forPossibleKeys: ["userId", "uid"])
        keyId = container.decodeInt(forPossibleKeys: ["keyId", "accessKeyId"])
        keyName = container.decodeString(forPossibleKeys: ["keyName", "accessKeyName"])
        providerId = container.decodeInt(forPossibleKeys: ["providerId"])
        providerName = container.decodeString(forPossibleKeys: ["providerName", "provider"])
        model = container.decodeString(forPossibleKeys: ["model", "modelName"])
        apiType = container.decodeString(forPossibleKeys: ["apiType", "endpoint", "type"])
        startTime = container.decodeDate(forPossibleKeys: ["startTime", "startedAt", "createdAt"])
        inputTokens = container.decodeInt(forPossibleKeys: ["inputTokens", "promptTokens"])
        outputTokens = container.decodeInt(forPossibleKeys: ["outputTokens", "completionTokens"])
        cacheCreationInputTokens = container.decodeInt(forPossibleKeys: ["cacheCreationInputTokens", "cacheWriteTokens"])
        cacheReadInputTokens = container.decodeInt(forPossibleKeys: ["cacheReadInputTokens", "cacheReadTokens"])
        totalTokens = container.decodeInt(forPossibleKeys: ["totalTokens", "tokens"])
        cost = container.decodeDouble(forPossibleKeys: ["costUsd", "cost", "totalCost"])
        status = container.decodeString(forPossibleKeys: ["status", "state"])
        durationMs = container.decodeInt(forPossibleKeys: ["durationMs", "duration"])
        requestCount = container.decodeInt(forPossibleKeys: ["requestCount", "requests"])
        concurrentCount = container.decodeInt(forPossibleKeys: ["concurrentCount", "concurrent"])
    }
}

enum DashboardLeaderboardScope: String {
    case user
    case provider
    case model
}

enum DashboardLeaderboardPeriod: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case allTime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .allTime: return "All Time"
        }
    }
}

struct DashboardUsageLogsFilter: Equatable {
    let search: String?
    let userId: Int?
    let providerId: Int?
    let sessionId: String?

    init(search: String? = nil, userId: Int? = nil, providerId: Int? = nil, sessionId: String? = nil) {
        self.search = search?.nilIfBlank
        self.userId = userId
        self.providerId = providerId
        self.sessionId = sessionId?.nilIfBlank
    }
}

struct DashboardLeaderboardEntry: Decodable, Equatable, Identifiable {
    let id: String
    let name: String
    let totalRequests: Int
    let totalCost: Double
    let totalTokens: Int
    let successRate: Double?
    let modelStats: [DashboardLeaderboardEntry]

    init(
        id: String,
        name: String,
        totalRequests: Int,
        totalCost: Double,
        totalTokens: Int,
        successRate: Double? = nil,
        modelStats: [DashboardLeaderboardEntry] = []
    ) {
        self.id = id
        self.name = name
        self.totalRequests = totalRequests
        self.totalCost = totalCost
        self.totalTokens = totalTokens
        self.successRate = successRate
        self.modelStats = modelStats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        if let userId = container.decodeInt(forPossibleKeys: ["userId"]) {
            id = "user-\(userId)"
        } else if let providerId = container.decodeInt(forPossibleKeys: ["providerId"]) {
            id = "provider-\(providerId)"
        } else {
            let model = container.decodeString(forPossibleKeys: ["model"]) ?? UUID().uuidString
            id = "model-\(model)"
        }
        name = container.decodeString(forPossibleKeys: ["userName", "providerName", "model", "name"]) ?? "Unknown"
        totalRequests = container.decodeInt(forPossibleKeys: ["totalRequests", "requests"]) ?? 0
        totalCost = container.decodeDouble(forPossibleKeys: ["totalCost", "cost"]) ?? 0
        totalTokens = container.decodeInt(forPossibleKeys: ["totalTokens", "tokens"]) ?? 0
        successRate = container.decodeDouble(forPossibleKeys: ["successRate"])
        modelStats = (try? container.decode([DashboardLeaderboardEntry].self, forKey: DynamicCodingKey(stringValue: "modelStats")!)) ?? []
    }
}

struct AdminAPIKey: Decodable, Equatable, Identifiable {
    let id: Int
    let name: String
    let maskedKey: String?
    let status: String?
    let todayUsage: Double?
    let todayTokens: Int?
    let todayCallCount: Int?
    let lastUsedAt: Date?
    let lastProviderName: String?
    let providerGroup: String?

    var isEnabled: Bool {
        let normalized = status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == nil || ["enabled", "active", "ok"].contains(normalized!)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = container.decodeInt(forPossibleKeys: ["id", "keyId"]) ?? 0
        name = container.decodeString(forPossibleKeys: ["name", "keyName"]) ?? "Key \(id)"
        maskedKey = container.decodeString(forPossibleKeys: ["maskedKey", "key"])
        status = container.decodeString(forPossibleKeys: ["status", "state"])
        todayUsage = container.decodeDouble(forPossibleKeys: ["todayUsage", "todayTotalCostUsd", "cost"])
        todayTokens = container.decodeInt(forPossibleKeys: ["todayTokens", "tokens", "totalTokens"])
        todayCallCount = container.decodeInt(forPossibleKeys: ["todayCallCount", "calls", "requestCount"])
        lastUsedAt = container.decodeDate(forPossibleKeys: ["lastUsedAt", "lastCallTime"])
        lastProviderName = container.decodeString(forPossibleKeys: ["lastProviderName", "providerName"])
        providerGroup = container.decodeString(forPossibleKeys: ["providerGroup", "groupTag"])
    }
}

struct AdminUser: Decodable, Equatable, Identifiable {
    let id: Int
    let name: String
    let role: String?
    let providerGroup: String?
    let tags: [String]
    let isEnabled: Bool
    let todayUsage: Double?
    let todayTokens: Int?
    let rpm: Int?
    let dailyQuota: Double?
    let limitDailyUsd: Double?
    let expiresAt: Date?
    let keys: [AdminAPIKey]

    var searchableText: String {
        ([name, role, providerGroup] + tags + keys.flatMap { [$0.name, $0.maskedKey, $0.lastProviderName] })
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = container.decodeInt(forPossibleKeys: ["id", "userId"]) ?? 0
        name = container.decodeString(forPossibleKeys: ["name", "userName", "username"]) ?? "User \(id)"
        role = container.decodeString(forPossibleKeys: ["role"])
        providerGroup = container.decodeString(forPossibleKeys: ["providerGroup", "groupTag"])
        tags = (try? container.decode([String].self, forKey: DynamicCodingKey(stringValue: "tags")!)) ?? []
        isEnabled = container.decodeBool(forPossibleKeys: ["isEnabled", "enabled"]) ?? true
        todayUsage = container.decodeDouble(forPossibleKeys: ["todayUsage", "todayTotalCostUsd", "cost"])
        todayTokens = container.decodeInt(forPossibleKeys: ["todayTokens", "tokens", "totalTokens"])
        rpm = container.decodeInt(forPossibleKeys: ["rpm", "limitRpm"])
        dailyQuota = container.decodeDouble(forPossibleKeys: ["dailyQuota", "limitDailyUsd"])
        limitDailyUsd = container.decodeDouble(forPossibleKeys: ["limitDailyUsd"])
        expiresAt = container.decodeDate(forPossibleKeys: ["expiresAt", "expireAt"])
        keys = (try? container.decode([AdminAPIKey].self, forKey: DynamicCodingKey(stringValue: "keys")!)) ?? []
    }
}

struct AdminProvider: Decodable, Equatable, Identifiable {
    let id: Int
    let name: String
    let url: String?
    let maskedKey: String?
    let isEnabled: Bool
    let weight: Int?
    let priority: Int?
    let groupTag: String?
    let providerType: String?
    let costMultiplier: Double?
    let rpm: Int?
    let tpm: Int?
    let rpd: Int?
    let todayTotalCostUsd: Double?
    let todayCallCount: Int?
    let lastCallTime: Date?
    let lastCallModel: String?

    var searchableText: String {
        [name, url, maskedKey, groupTag, providerType, lastCallModel]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = container.decodeInt(forPossibleKeys: ["id", "providerId"]) ?? 0
        name = container.decodeString(forPossibleKeys: ["name", "providerName"]) ?? "Provider \(id)"
        url = container.decodeString(forPossibleKeys: ["url", "endpointUrl", "websiteUrl"])
        maskedKey = container.decodeString(forPossibleKeys: ["maskedKey", "key"])
        isEnabled = container.decodeBool(forPossibleKeys: ["isEnabled", "enabled"]) ?? true
        weight = container.decodeInt(forPossibleKeys: ["weight"])
        priority = container.decodeInt(forPossibleKeys: ["priority"])
        groupTag = container.decodeString(forPossibleKeys: ["groupTag", "providerGroup"])
        providerType = container.decodeString(forPossibleKeys: ["providerType", "type"])
        costMultiplier = container.decodeDouble(forPossibleKeys: ["costMultiplier"])
        rpm = container.decodeInt(forPossibleKeys: ["rpm"])
        tpm = container.decodeInt(forPossibleKeys: ["tpm"])
        rpd = container.decodeInt(forPossibleKeys: ["rpd"])
        todayTotalCostUsd = container.decodeDouble(forPossibleKeys: ["todayTotalCostUsd", "todayUsage", "cost"])
        todayCallCount = container.decodeInt(forPossibleKeys: ["todayCallCount", "calls", "requestCount"])
        lastCallTime = container.decodeDate(forPossibleKeys: ["lastCallTime", "lastUsedAt"])
        lastCallModel = container.decodeString(forPossibleKeys: ["lastCallModel", "model"])
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct StringListResponse: Decodable, Equatable {
    let values: [String]

    init(values: [String]) {
        self.values = values
    }

    init(from decoder: Decoder) throws {
        if let strings = try? [String](from: decoder) {
            values = strings.sorted()
            return
        }
        if let objects = try? [NamedValue](from: decoder) {
            values = objects.compactMap(\.name).sorted()
            return
        }

        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        for key in ["items", "models", "endpoints", "data", "values", "list"] {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            if let strings = try? container.decode([String].self, forKey: codingKey) {
                values = strings.sorted()
                return
            }
            if let objects = try? container.decode([NamedValue].self, forKey: codingKey) {
                values = objects.compactMap(\.name).sorted()
                return
            }
        }
        values = []
    }
}

private struct NamedValue: Decodable, Equatable {
    let name: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        name = container.decodeString(forPossibleKeys: ["name", "id", "model", "endpoint", "path", "value"])
    }
}

struct ServerTimeZoneResponse: Decodable, Equatable {
    let identifier: String?

    init(identifier: String?) {
        self.identifier = identifier
    }

    init(from decoder: Decoder) throws {
        if let string = try? String(from: decoder) {
            identifier = string
            return
        }
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        identifier = container.decodeString(forPossibleKeys: ["timezone", "timeZone", "timeZoneId", "zone", "identifier"])
    }
}
