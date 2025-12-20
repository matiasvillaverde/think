import Abstractions
import Foundation
import OSLog

/// Strategy for health data access tool
public struct HealthKitStrategy: ToolStrategy {
    /// Logger for health kit tool operations
    private static let logger: Logger = Logger(subsystem: "Tools", category: "HealthKitStrategy")
    internal let healthKitManager: HealthKitManager = HealthKitManager()

    /// The tool definition
    public let definition: ToolDefinition = ToolDefinition(
        name: "health_data",
        description: "Read health and fitness data from HealthKit",
        schema: """
        {
            "type": "object",
            "properties": {
                "dataType": {
                    "type": "string",
                    "description": "Type of health data to retrieve",
                    "enum": ["steps", "heartRate", "sleep", "workout", "calories", "distance"]
                },
                "startDate": {
                    "type": "string",
                    "description": "Start date in ISO format (YYYY-MM-DD)",
                    "format": "date"
                },
                "endDate": {
                    "type": "string",
                    "description": "End date in ISO format (YYYY-MM-DD)",
                    "format": "date"
                },
                "limit": {
                    "type": "integer",
                    "description": "Maximum number of results to return",
                    "minimum": 1,
                    "maximum": 100,
                    "default": 50
                }
            },
            "required": ["dataType"]
        }
        """
    )

    /// Supported health data types
    private static let supportedTypes: [String] = [
        "steps", "heartRate", "sleep", "workout", "calories", "distance"
    ]

    /// Initialize a new HealthKitStrategy
    public init() {
        // No initialization required
    }

    /// Execute the health data request
    /// - Parameter request: The tool request
    /// - Returns: The tool response with health data
    public func execute(request: ToolRequest) -> ToolResponse {
        Self.logger.debug("Processing health data request for request ID: \(request.id)")

        // Parse arguments
        switch BaseToolStrategy.parseArguments(request) {
        case .failure(let error):
            return BaseToolStrategy.errorResponse(request: request, error: error.message)

        case .success(let json):
            return executeHealthDataRequest(request: request, json: json)
        }
    }

    /// Execute health data request with validation and fetching
    private func executeHealthDataRequest(request: ToolRequest, json: [String: Any]) -> ToolResponse {
        // Validate and extract parameters
        guard let dataType = json["dataType"] as? String else {
            Self.logger.warning("Health data request missing dataType parameter")
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Missing required parameter: dataType"
            )
        }

        // Validate supported data types
        guard Self.supportedTypes.contains(dataType) else {
            Self.logger.warning("Unsupported health data type requested: \(dataType)")
            let supportedList: String = Self.supportedTypes.joined(separator: ", ")
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Unsupported data type: \(dataType). Supported types: \(supportedList)"
            )
        }

        // Extract optional parameters
        let startDate: String? = json["startDate"] as? String
        let endDate: String? = json["endDate"] as? String
        let limit: Int = json["limit"] as? Int ?? ToolConstants.defaultHealthDataLimit

        Self.logger.info("Fetching health data type: \(dataType, privacy: .public)")
        Self.logger.debug(
            "Health data parameters - startDate: \(startDate ?? "nil"), endDate: \(endDate ?? "nil"), limit: \(limit)"
        )

        return performHealthDataFetch(
            request: request,
            dataType: dataType,
            startDate: startDate,
            endDate: endDate,
            limit: limit
        )
    }

    /// Perform the actual health data fetch with async handling
    private func performHealthDataFetch(
        request: ToolRequest,
        dataType: String,
        startDate: String?,
        endDate: String?,
        limit: Int
    ) -> ToolResponse {
        let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
        var response: ToolResponse?

        Task {
            do {
                let result: String = try await fetchHealthData(
                    dataType: dataType,
                    startDate: startDate,
                    endDate: endDate,
                    limit: limit
                )
                Self.logger.notice("Health data fetched successfully")
                response = BaseToolStrategy.successResponse(
                    request: request,
                    result: result
                )
            } catch {
                Self.logger.error("Health data fetch failed: \(error.localizedDescription)")
                response = BaseToolStrategy.errorResponse(
                    request: request,
                    error: "Failed to fetch health data: \(error.localizedDescription)"
                )
            }
            semaphore.signal()
        }

        let timeoutSeconds: Double = 10.0
        _ = semaphore.wait(timeout: .now() + timeoutSeconds)

        return response ?? BaseToolStrategy.errorResponse(
            request: request,
            error: "Health data fetch timed out"
        )
    }

    /// Fetch health data using HealthKitManager
    /// - Parameters:
    ///   - dataType: Type of health data
    ///   - startDate: Optional start date string
    ///   - endDate: Optional end date string
    ///   - limit: Maximum number of results
    /// - Returns: Formatted health data string
    private func fetchHealthData(
        dataType: String,
        startDate: String?,
        endDate: String?,
        limit: Int
    ) async throws -> String {
        // Parse dates
        let formatter: ISO8601DateFormatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        let defaultDays: Double = 7
        let endDateParsed: Date = endDate.flatMap { formatter.date(from: $0) } ?? Date()
        let startDateParsed: Date = startDate.flatMap { formatter.date(from: $0) }
            ?? endDateParsed.addingTimeInterval(-defaultDays * ToolConstants.secondsPerDay)

        // Check authorization
        if !healthKitManager.isHealthKitAvailable() {
            // Fall back to mock data when HealthKit not available
            return generateMockHealthData(
                dataType: dataType,
                startDate: startDateParsed,
                endDate: endDateParsed,
                limit: limit
            )
        }

        // Fetch data based on type
        switch dataType {
        case "steps":
            let dataPoints: [HealthKitManager.HealthDataPoint] = try await healthKitManager.fetchSteps(
                from: startDateParsed,
                to: endDateParsed
            )
            return formatStepsData(dataPoints, dateRange: formatDateRange(startDate: startDate, endDate: endDate))

        case "heartRate":
            let dataPoints: [HealthKitManager.HealthDataPoint] = try await healthKitManager.fetchHeartRate(
                from: startDateParsed,
                to: endDateParsed
            )
            return formatHeartRateData(dataPoints.prefix(limit))

        case "sleep":
            return HealthDataFormatter.formatSleep(dateRange: formatDateRange(startDate: startDate, endDate: endDate))

        case "workout":
            return HealthDataFormatter.formatWorkout(dateRange: formatDateRange(startDate: startDate, endDate: endDate))

        case "calories":
            let dataPoints: [HealthKitManager.HealthDataPoint] = try await healthKitManager.fetchCalories(
                from: startDateParsed,
                to: endDateParsed
            )
            return formatCaloriesData(dataPoints, dateRange: formatDateRange(startDate: startDate, endDate: endDate))

        case "distance":
            let dataPoints: [HealthKitManager.HealthDataPoint] = try await healthKitManager.fetchDistance(
                from: startDateParsed,
                to: endDateParsed
            )
            return formatDistanceData(dataPoints, dateRange: formatDateRange(startDate: startDate, endDate: endDate))

        default:
            throw HealthKitManager.HealthKitError.noData
        }
    }
}
