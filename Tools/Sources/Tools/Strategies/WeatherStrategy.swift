import Abstractions
import Foundation
import OSLog

/// Strategy for weather information tool
public struct WeatherStrategy: ToolStrategy {
    /// Logger for weather tool operations
    private static let logger: Logger = Logger(subsystem: "Tools", category: "WeatherStrategy")
    /// The tool definition
    public let definition: ToolDefinition = ToolDefinition(
        name: "weather",
        description: "Get weather information for a specific location",
        schema: """
        {
            "type": "object",
            "properties": {
                "location": {
                    "type": "string",
                    "description": "City and country/state (e.g., 'San Francisco, CA')"
                },
                "units": {
                    "type": "string",
                    "description": "Temperature units",
                    "enum": ["celsius", "fahrenheit", "kelvin"],
                    "default": "celsius"
                },
                "forecast": {
                    "type": "boolean",
                    "description": "Include forecast",
                    "default": false
                },
                "days": {
                    "type": "integer",
                    "description": "Number of forecast days (1-7)",
                    "minimum": 1,
                    "maximum": 7,
                    "default": 3
                },
                "detailed": {
                    "type": "boolean",
                    "description": "Include detailed weather information",
                    "default": false
                }
            },
            "required": ["location"]
        }
        """
    )

    /// Initialize a new WeatherStrategy
    public init() {
        // No initialization required
    }

    /// Execute the weather request
    /// - Parameter request: The tool request
    /// - Returns: The tool response with weather information
    public func execute(request: ToolRequest) -> ToolResponse {
        Self.logger.debug("Processing weather request for request ID: \(request.id)")

        // Parse arguments
        switch BaseToolStrategy.parseArguments(request) {
        case .failure(let error):
            return BaseToolStrategy.errorResponse(request: request, error: error.message)

        case .success(let json):
            // Validate required location parameter
            guard let location = json["location"] as? String, !location.isEmpty else {
                Self.logger.warning("Weather request missing location parameter")
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: "Missing required parameter: location"
                )
            }

            // Extract optional parameters
            let units: String = json["units"] as? String ?? "celsius"
            let forecast: Bool = json["forecast"] as? Bool ?? false
            let forecastDaysDefault: Int = 3
            let days: Int = json["days"] as? Int ?? forecastDaysDefault
            let detailed: Bool = json["detailed"] as? Bool ?? false

            Self.logger.info("Generating weather report for location: \(location, privacy: .public)")
            Self.logger.debug(
                "Weather parameters - units: \(units), forecast: \(forecast), days: \(days), detailed: \(detailed)"
            )

            // Generate weather report
            let result: String = generateWeatherReport(
                location: location,
                units: units,
                forecast: forecast,
                days: days,
                detailed: detailed
            )

            Self.logger.notice("Weather report generated successfully")

            return BaseToolStrategy.successResponse(
                request: request,
                result: result
            )
        }
    }

    /// Generate weather report
    private func generateWeatherReport(
        location: String,
        units: String,
        forecast: Bool,
        days: Int,
        detailed: Bool
    ) -> String {
        let tempUnit: String = getTemperatureUnit(units)
        let currentTemp: Int = generateRandomTemperature(units: units)

        var report: String = "Weather for \(location)\n"
        report += "─────────────────────\n"
        report += "Current: \(currentTemp)\(tempUnit)\n"
        report += "Conditions: Partly Cloudy\n"

        if detailed {
            report += "\nDetailed Information:\n"
            report += "• Humidity: 65%\n"
            report += "• Wind: 12 mph NW\n"
            report += "• Pressure: 1013 hPa\n"
            report += "• Visibility: 10 miles\n"
            report += "• UV Index: 3 (Moderate)\n"
        }

        if forecast {
            report += "\n\(days)-day forecast:\n"
            let tempIncreaseMin: Int = 2
            let tempIncreaseMax: Int = 8
            let tempDecreaseMin: Int = 2
            let tempDecreaseMax: Int = 6
            for day in 1...days {
                let highTemp: Int = currentTemp + Int.random(in: tempIncreaseMin...tempIncreaseMax)
                let lowTemp: Int = currentTemp - Int.random(in: tempDecreaseMin...tempDecreaseMax)
                report += "Day \(day): High \(highTemp)\(tempUnit), Low \(lowTemp)\(tempUnit)\n"
            }
        }

        return report
    }

    /// Get temperature unit symbol
    private func getTemperatureUnit(_ units: String) -> String {
        switch units {
        case "fahrenheit":
            return "°F"

        case "kelvin":
            return "K"

        default:
            return "°C"
        }
    }

    /// Generate random temperature based on units
    private func generateRandomTemperature(units: String) -> Int {
        switch units {
        case "fahrenheit":
            let fahrenheitBase: Int = 68
            let fahrenheitVariation: Int = 15
            return fahrenheitBase + Int.random(in: -fahrenheitVariation...fahrenheitVariation)

        case "kelvin":
            let kelvinBase: Int = 293
            let kelvinVariation: Int = 10
            return kelvinBase + Int.random(in: -kelvinVariation...kelvinVariation)

        default: // celsius
            let celsiusBase: Int = 20
            let celsiusVariation: Int = 10
            return celsiusBase + Int.random(in: -celsiusVariation...celsiusVariation)
        }
    }
}
