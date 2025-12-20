@testable import Abstractions
import Foundation
import Testing
@testable import Tools

@Suite("WeatherStrategy Tests")
internal struct WeatherStrategyTests {
    @Test("WeatherStrategy has correct tool definition")
    func testToolDefinition() {
        // Given
        let strategy: WeatherStrategy = WeatherStrategy()

        // When
        let definition: ToolDefinition = strategy.definition

        // Then
        #expect(definition.name == "weather")
        #expect(definition.description.contains("weather"))
        #expect(definition.schema.contains("location"))
    }

    @Test("WeatherStrategy gets current weather for location")
    func testGetCurrentWeather() {
        // Given
        let strategy: WeatherStrategy = WeatherStrategy()
        let request: ToolRequest = ToolRequest(
            name: "weather",
            arguments: """
            {
                "location": "San Francisco, CA",
                "units": "fahrenheit"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.requestId == request.id)
        #expect(response.toolName == "weather")
        #expect(response.error == nil)
        #expect(response.result.contains("San Francisco"))
        #expect(response.result.contains("°F"))
    }

    @Test("WeatherStrategy handles missing location")
    func testMissingLocation() {
        // Given
        let strategy: WeatherStrategy = WeatherStrategy()
        let request: ToolRequest = ToolRequest(
            name: "weather",
            arguments: "{}",
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.error != nil)
        #expect(response.error?.contains("location") == true)
    }

    @Test("WeatherStrategy supports forecast")
    func testGetForecast() {
        // Given
        let strategy: WeatherStrategy = WeatherStrategy()
        let request: ToolRequest = ToolRequest(
            name: "weather",
            arguments: """
            {
                "location": "London, UK",
                "forecast": true,
                "days": 3
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        #expect(response.result.contains("London"))
        #expect(response.result.contains("3-day forecast"))
    }

    @Test("WeatherStrategy uses celsius units")
    func testCelsiusUnits() {
        // Given
        let strategy: WeatherStrategy = WeatherStrategy()
        let request: ToolRequest = ToolRequest(
            name: "weather",
            arguments: """
            {
                "location": "Paris, France",
                "units": "celsius"
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        #expect(response.result.contains("°C"))
    }

    @Test("WeatherStrategy includes detailed information")
    func testDetailedWeather() {
        // Given
        let strategy: WeatherStrategy = WeatherStrategy()
        let request: ToolRequest = ToolRequest(
            name: "weather",
            arguments: """
            {
                "location": "Tokyo, Japan",
                "detailed": true
            }
            """,
            id: UUID()
        )

        // When
        let response: ToolResponse = strategy.execute(request: request)

        // Then
        #expect(response.error == nil)
        #expect(response.result.contains("Humidity"))
        #expect(response.result.contains("Wind"))
        #expect(response.result.contains("Pressure"))
    }
}
