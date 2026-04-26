import Foundation
import XCTest
@testable import ClaudeCodeHubMobileCore

final class LiveServerIntegrationTests: XCTestCase {
    func testConfiguredClaudeCodeHubServerLoginAndReadOnlyActions() async throws {
        guard let baseURLString = ProcessInfo.processInfo.environment["CCH_BASE_URL"],
              let baseURL = URL(string: baseURLString),
              let accessKey = ProcessInfo.processInfo.environment["CCH_KEY"],
              !accessKey.isEmpty else {
            throw XCTSkip("Set CCH_BASE_URL and CCH_KEY to run live Claude Code Hub integration.")
        }

        let storage = HTTPCookieStorage.shared
        storage.cookies?.forEach { cookie in
            if let host = baseURL.host,
               cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).contains(host) {
                storage.deleteCookie(cookie)
            }
        }

        let client = APIClient(baseURL: baseURL)
        let login = try await client.login(accessKey: accessKey)
        XCTAssertNotEqual(login.success, false)

        let quota = try await client.getQuota()
        XCTAssertNotNil(quota.status)

        _ = try await client.getStatsSummary()
        _ = try await client.getAvailableModels()
        _ = try await client.getAvailableEndpoints()

        let logs = try await client.getUsageLogs(limit: 3)
        XCTAssertNotNil(logs.hasMore)

        _ = try await client.getServerTimeZone()

        if login.isAdmin {
            let dashboardOverview = try await client.getDashboardOverview()
            XCTAssertNotNil(dashboardOverview.totalRequests)

            let dashboardLogs = try await client.getDashboardUsageLogs(limit: 5)
            XCTAssertFalse(dashboardLogs.records.isEmpty)

            let dashboardModels = try await client.getDashboardAvailableModels()
            XCTAssertFalse(dashboardModels.isEmpty)
        }
    }
}
