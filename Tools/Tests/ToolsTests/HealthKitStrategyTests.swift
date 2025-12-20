@testable import Abstractions
import Foundation
import Testing
@testable import Tools

@Suite("HealthKitStrategy Tests")
internal struct HealthKitStrategyTests {
    @Test("HealthKitStrategy has correct tool definition")
    func testToolDefinition() {
        // Given
        let strategy: HealthKitStrategy = HealthKitStrategy()

        // When
        let definition: ToolDefinition = strategy.definition

        // Then
        #expect(definition.name == "health_data")
        #expect(definition.description.contains("health"))
        #expect(definition.schema.contains("dataType"))
    }

    @Test("HealthKitStrategy reads steps data")
    func testReadStepsData() async {
        // Given
        let strategy: HealthKitStrategy = HealthKitStrategy()
        let request: ToolRequest = ToolRequest(
            name: "health_data",
            arguments: """
            {
                "dataType": "steps",
                "startDate": "2024-01-01",
                "endDate": "2024-01-31"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.requestId == request.id)
        #expect(response.toolName == "health_data")
        #expect(response.error == nil)
        #expect(response.result.contains("steps"))
    }

    @Test("HealthKitStrategy handles invalid data type")
    func testInvalidDataType() async {
        // Given
        let strategy: HealthKitStrategy = HealthKitStrategy()
        let request: ToolRequest = ToolRequest(
            name: "health_data",
            arguments: """
            {
                "dataType": "invalid_type"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("Unsupported data type") == true)
    }

    @Test("HealthKitStrategy requires dataType parameter")
    func testMissingDataType() async {
        // Given
        let strategy: HealthKitStrategy = HealthKitStrategy()
        let request: ToolRequest = ToolRequest(
            name: "health_data",
            arguments: "{}",
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("dataType") == true)
    }

    @Test("HealthKitStrategy reads heart rate data")
    func testReadHeartRateData() async {
        // Given
        let strategy: HealthKitStrategy = HealthKitStrategy()
        let request: ToolRequest = ToolRequest(
            name: "health_data",
            arguments: """
            {
                "dataType": "heartRate",
                "limit": 10
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        #expect(response.result.contains("Heart rate"))
    }

    @Test("HealthKitStrategy uses default date range")
    func testDefaultDateRange() async {
        // Given
        let strategy: HealthKitStrategy = HealthKitStrategy()
        let request: ToolRequest = ToolRequest(
            name: "health_data",
            arguments: """
            {
                "dataType": "steps"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = await strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        #expect(response.result.contains("last 7 days"))
    }
}
