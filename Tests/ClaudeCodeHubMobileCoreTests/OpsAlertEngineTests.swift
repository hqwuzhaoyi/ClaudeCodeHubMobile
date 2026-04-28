import XCTest
@testable import ClaudeCodeHubMobileCore

final class OpsAlertEngineTests: XCTestCase {
    func testCriticalErrorRateProducesActionableAlert() {
        let stats = StatsSummary(todayErrorRate: 18.5)

        let alerts = OpsAlertEngine.alerts(stats: stats, circuitBreakerProviders: [])

        XCTAssertEqual(alerts.first?.severity, .critical)
        XCTAssertEqual(alerts.first?.kind, .errorRate)
        XCTAssertTrue(alerts.first?.message.contains("18.5%") == true)
        XCTAssertTrue(alerts.first?.recommendedAction.contains("Logs") == true)
    }

    func testCostSpikeComparesAgainstYesterdaySamePeriod() {
        let stats = StatsSummary(totalCost: 210, yesterdaySamePeriodCost: 100)

        let alerts = OpsAlertEngine.alerts(stats: stats, circuitBreakerProviders: [])

        XCTAssertTrue(alerts.contains { alert in
            alert.kind == .costSpike && alert.severity == .critical && alert.message.contains("+110%")
        })
    }

    func testOpenProviderCircuitProducesProviderAlert() {
        let providerData = Data("""
        {
          "id": 98,
          "name": "Fallback Provider",
          "isEnabled": true,
          "providerType": "codex"
        }
        """.utf8)
        let health = ProviderHealthStatus(providerId: 98, circuitState: "half_open", failureCount: 4, lastFailureTime: nil)
        let provider = try! JSONDecoder().decode(AdminProvider.self, from: providerData)

        let alerts = OpsAlertEngine.alerts(
            stats: StatsSummary(),
            circuitBreakerProviders: [CircuitBreakerProvider(provider: provider, health: health)]
        )

        XCTAssertEqual(alerts.first?.kind, .providerCircuit)
        XCTAssertEqual(alerts.first?.severity, .warning)
        XCTAssertTrue(alerts.first?.title.contains("Provider circuit") == true)
    }

    func testCircuitBreakerProvidersMatchesOpenHealthToProviderDetails() {
        let providers = [
            decodeProvider(id: 2, name: "Beta Provider"),
            decodeProvider(id: 1, name: "Alpha Provider"),
        ]
        let healthStatuses = [
            ProviderHealthStatus(providerId: 2, circuitState: "closed", failureCount: 0, lastFailureTime: nil),
            ProviderHealthStatus(providerId: 1, circuitState: "open", failureCount: 3, lastFailureTime: nil),
        ]

        let fused = OpsAlertEngine.circuitBreakerProviders(providers: providers, healthStatuses: healthStatuses)

        XCTAssertEqual(fused.map(\.id), [1])
        XCTAssertEqual(fused.first?.provider.name, "Alpha Provider")
        XCTAssertEqual(fused.first?.health.failureCount, 3)
    }

    private func decodeProvider(id: Int, name: String) -> AdminProvider {
        let data = Data("""
        {
          "id": \(id),
          "name": "\(name)",
          "isEnabled": true,
          "providerType": "codex"
        }
        """.utf8)
        return try! JSONDecoder().decode(AdminProvider.self, from: data)
    }
}
