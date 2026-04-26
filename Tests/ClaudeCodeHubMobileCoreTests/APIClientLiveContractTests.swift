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
        XCTAssertEqual(response.records.first?.endpoint, "chat")
        XCTAssertEqual(response.records.first?.cost, 50.393444)
        XCTAssertEqual(response.records.first?.totalTokens, 37157355)
        XCTAssertEqual(response.total, 321173)
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
