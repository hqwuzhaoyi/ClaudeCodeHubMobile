import Foundation
import XCTest
@testable import ClaudeCodeHubMobileCore

final class APIClientLiveContractTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testQuotaUsesLiveMyUsageActionPathAndDecodesDailyQuotaShape() async throws {
        let client = makeClient(responseBody: """
        {
          "ok": true,
          "data": {
            "keyLimitDailyUsd": 10,
            "keyCurrentDailyUsd": 3.25,
            "keyIsEnabled": true,
            "expiresAt": "2026-04-30T00:00:00Z"
          }
        }
        """)

        let quota = try await client.getQuota()

        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.path, "/api/actions/my-usage/getMyQuota")
        XCTAssertEqual(quota.status, "active")
        XCTAssertEqual(quota.quota, 10)
        XCTAssertEqual(quota.used, 3.25)
        XCTAssertEqual(quota.remaining, 6.75)
        XCTAssertNotNil(quota.expiresAt)
    }

    func testLogsUseBatchActionAndRoundTripObjectCursor() async throws {
        let client = makeClient(responseBody: """
        {
          "ok": true,
          "data": {
            "logs": [
              {
                "id": 42,
                "createdAt": "2026-04-26T08:00:00Z",
                "model": "claude-sonnet",
                "endpoint": "/v1/messages",
                "statusCode": 200,
                "cost": 0.12,
                "inputTokens": 100,
                "outputTokens": 20
              }
            ],
            "nextCursor": { "createdAt": "2026-04-26T08:00:00Z", "id": 42 },
            "hasMore": true,
            "currencyCode": "USD"
          }
        }
        """)

        let response = try await client.getUsageLogs(limit: 1)

        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.path, "/api/actions/my-usage/getMyUsageLogsBatch")
        XCTAssertEqual(response.records.count, 1)
        XCTAssertEqual(response.records.first?.id, "42")
        XCTAssertEqual(response.records.first?.statusCategory, "success")
        XCTAssertEqual(response.nextCursor?.createdAt, "2026-04-26T08:00:00Z")
        XCTAssertEqual(response.nextCursor?.id, 42)
        XCTAssertEqual(response.hasMore, true)
    }

    func testServerTimezoneUsesSystemSettingsRoute() async throws {
        let client = makeClient(responseBody: """
        { "timezone": "Asia/Shanghai", "siteTitle": "Claude Code Hub" }
        """)

        let timeZone = try await client.getServerTimeZone()

        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.path, "/api/system-settings")
        XCTAssertEqual(timeZone, "Asia/Shanghai")
        XCTAssertEqual(AppFormatters.serverTimeZone?.identifier, "Asia/Shanghai")
    }

    func testDashboardOverviewDecodesHomeBentoComparisonMetrics() async throws {
        let client = makeClient(responseBody: """
        {
          "ok": true,
          "data": {
            "concurrentSessions": 4,
            "todayRequests": 3880,
            "todayCost": 1019.096797,
            "avgResponseTime": 15054,
            "todayErrorRate": 15.26,
            "yesterdaySamePeriodRequests": 4430,
            "yesterdaySamePeriodCost": 587.104931,
            "yesterdaySamePeriodAvgResponseTime": 11446,
            "recentMinuteRequests": 5
          }
        }
        """)

        let overview = try await client.getDashboardOverview()

        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.path, "/api/actions/overview/getOverviewData")
        XCTAssertEqual(overview.concurrentSessions, 4)
        XCTAssertEqual(overview.totalRequests, 3880)
        XCTAssertEqual(overview.totalCost, 1019.096797)
        XCTAssertEqual(overview.avgResponseTimeMs, 15054)
        XCTAssertEqual(overview.todayErrorRate, 15.26)
        XCTAssertEqual(overview.yesterdaySamePeriodRequests, 4430)
        XCTAssertEqual(overview.yesterdaySamePeriodCost, 587.104931)
        XCTAssertEqual(overview.yesterdaySamePeriodAvgResponseTimeMs, 11446)
        XCTAssertEqual(overview.recentMinuteRequests, 5)
    }

    func testDashboardLeaderboardUsesWebHomeEndpointAndDecodesScopes() async throws {
        let client = makeClient(responseBody: """
        [
          {
            "userId": 2,
            "userName": "codex",
            "totalRequests": 2501,
            "totalCost": 997.308872,
            "totalTokens": 872923344
          }
        ]
        """)

        let entries = try await client.getDashboardLeaderboard(scope: .user)

        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.path, "/api/leaderboard")
        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.query, "period=daily&scope=user")
        XCTAssertEqual(entries.first?.id, "user-2")
        XCTAssertEqual(entries.first?.name, "codex")
        XCTAssertEqual(entries.first?.totalRequests, 2501)
        XCTAssertEqual(entries.first?.totalCost, 997.308872)
        XCTAssertEqual(entries.first?.totalTokens, 872923344)
    }

    func testLoginSendsSameOriginFetchMetadataForClaudeCodeHubCsrfGuard() async throws {
        let client = makeClient(responseBody: """
        { "ok": true, "loginType": "admin", "redirectTo": "/dashboard" }
        """)

        _ = try await client.login(accessKey: "test-key")

        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.path, "/api/auth/login")
        XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Sec-Fetch-Site"), "same-origin")
    }

    func testDashboardLogsDecodeAdminUsageLogShape() async throws {
        let client = makeClient(responseBody: """
        {
          "ok": true,
          "data": {
            "logs": [
              {
                "id": 7,
                "createdAt": "2026-04-27T00:00:00Z",
                "sessionId": "session-1",
                "userName": "codex",
                "keyName": "default",
                "providerName": "Right Code Codex",
                "model": "gpt-5.5",
                "apiType": "chat",
                "statusCode": 200,
                "costUsd": "50.393444000000000",
                "inputTokens": 964568,
                "outputTokens": 77203,
                "cacheReadInputTokens": 36115584,
                "totalTokens": 37157355
              }
            ],
            "total": 321173
          }
        }
        """)

        let response = try await client.getDashboardUsageLogs(limit: 5)

        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.path, "/api/actions/usage-logs/getUsageLogs")
        XCTAssertEqual(response.records.first?.id, "7")
        XCTAssertEqual(response.records.first?.sessionId, "session-1")
        XCTAssertEqual(response.records.first?.userName, "codex")
        XCTAssertEqual(response.records.first?.keyName, "default")
        XCTAssertEqual(response.records.first?.providerName, "Right Code Codex")
        XCTAssertEqual(response.records.first?.endpoint, "chat")
        XCTAssertEqual(response.records.first?.cost, 50.393444)
        XCTAssertEqual(response.records.first?.cacheReadInputTokens, 36115584)
        XCTAssertEqual(response.records.first?.totalTokens, 37157355)
        XCTAssertEqual(response.total, 321173)
    }

    func testDashboardInFlightUsageLogDisplaysRequestingInsteadOfUnknown() async throws {
        let client = makeClient(responseBody: """
        {
          "ok": true,
          "data": {
            "logs": [
              {
                "id": 8,
                "createdAt": "2026-04-27T00:00:01Z",
                "sessionId": "session-live",
                "requestSequence": 9,
                "model": "gpt-5.5",
                "endpoint": "/v1/responses",
                "durationMs": 1200
              }
            ]
          }
        }
        """)

        let response = try await client.getDashboardUsageLogs(limit: 1)

        XCTAssertEqual(response.records.first?.displayStatus, "requesting")
        XCTAssertEqual(response.records.first?.statusCategory, "requesting")
    }

    func testActiveSessionsUseDashboardMonitoringActionAndDecodeSessionAggregates() async throws {
        let client = makeClient(responseBody: """
        {
          "ok": true,
          "data": [
            {
              "sessionId": "019dca40-578b-7763-8784-0db9b80b3411",
              "userName": "codex",
              "userId": 2,
              "keyId": 2,
              "keyName": "default",
              "providerId": 4,
              "providerName": "88 Codex, Right Code Codex, 词元流动_Share",
              "model": "gpt-5.5",
              "apiType": "chat",
              "startTime": 1777223145725,
              "inputTokens": 1112,
              "outputTokens": 482,
              "cacheCreationInputTokens": 0,
              "cacheReadInputTokens": 64896,
              "totalTokens": 66490,
              "costUsd": "0.104936000000000",
              "status": "in_progress",
              "durationMs": 8292,
              "requestCount": 6,
              "concurrentCount": 1
            }
          ]
        }
        """)

        let sessions = try await client.getActiveSessions()

        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.path, "/api/actions/active-sessions/getActiveSessions")
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.sessionId, "019dca40-578b-7763-8784-0db9b80b3411")
        XCTAssertEqual(sessions.first?.startTime, Date(timeIntervalSince1970: 1777223145.725))
        XCTAssertEqual(sessions.first?.providerName, "88 Codex, Right Code Codex, 词元流动_Share")
        XCTAssertEqual(sessions.first?.cost, 0.104936)
        XCTAssertEqual(sessions.first?.cacheReadInputTokens, 64896)
        XCTAssertEqual(sessions.first?.isLive, true)
    }

    private func makeClient(responseBody: String, statusCode: Int = 200) -> APIClient {
        MockURLProtocol.statusCode = statusCode
        MockURLProtocol.responseData = Data(responseBody.utf8)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return APIClient(baseURL: URL(string: "https://cch.example.com")!, session: session)
    }
}

private final class MockURLProtocol: URLProtocol {
    static var responseData = Data()
    static var statusCode = 200
    static var lastRequest: URLRequest?

    static func reset() {
        responseData = Data()
        statusCode = 200
        lastRequest = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
