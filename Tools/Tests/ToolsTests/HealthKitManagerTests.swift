import Foundation
import Testing
@testable import Tools

@Suite("HealthKitManager Tests")
internal struct HealthKitManagerTests {
    @Test("HealthKitManager checks authorization status")
    internal func testAuthorizationStatus() {
        let manager: HealthKitManager = HealthKitManager()
        let isAuthorized: Bool = manager.isAuthorized()
        // In test environment, should return false
        #expect(!isAuthorized)
    }

    @Test("HealthKitManager fetches steps data")
    internal func testFetchStepsData() async throws {
        let manager: HealthKitManager = HealthKitManager()
        let startDate: Date = Date().addingTimeInterval(-86_400) // 1 day ago
        let endDate: Date = Date()

        let steps: [HealthKitManager.HealthDataPoint] = try await manager.fetchSteps(
            from: startDate,
            to: endDate
        )

        // In test environment, should return mock data
        #expect(!steps.isEmpty)
    }

    @Test("HealthKitManager fetches heart rate data")
    internal func testFetchHeartRateData() async throws {
        let manager: HealthKitManager = HealthKitManager()
        let startDate: Date = Date().addingTimeInterval(-3_600) // 1 hour ago
        let endDate: Date = Date()

        let heartRate: [HealthKitManager.HealthDataPoint] = try await manager.fetchHeartRate(
            from: startDate,
            to: endDate
        )

        // In test environment, should return mock data
        #expect(!heartRate.isEmpty)
    }

    @Test("HealthKitManager handles unavailable HealthKit")
    internal func testUnavailableHealthKit() {
        let manager: HealthKitManager = HealthKitManager()
        let available: Bool = manager.isHealthKitAvailable()

        // In test environment, HealthKit is not available
        #expect(!available)
    }

    @Test("HealthKitManager formats date ranges correctly")
    internal func testDateFormatting() {
        let manager: HealthKitManager = HealthKitManager()
        let startDate: Date = Date(timeIntervalSince1970: 1_700_000_000)
        let endDate: Date = Date(timeIntervalSince1970: 1_700_086_400)

        let formatted: String = manager.formatDateRange(from: startDate, to: endDate)
        #expect(formatted.contains("2023"))
    }
}
