import Abstractions
import Foundation
import Tools

/// A real tool strategy for testing that provides health data
internal final class TestHealthStrategy: ToolStrategy {
    private enum Constants {
        static let mockStepsValue: Double = 8_543.0
        static let mockDistanceValue: Double = 6.2
        static let mockCaloriesValue: Double = 2_100.0
        static let mockHeartRateValue: Double = 72.0
        static let defaultValue: Double = 0.0
    }

    internal struct HealthRecord {
        internal let metric: String
        internal let value: Double
        internal let unit: String
        internal let date: String
    }

    internal struct HealthParams {
        internal let metric: String
        internal let date: String
    }

    /// Thread-safe storage for execution history
    private final class ExecutionHistoryStorage: @unchecked Sendable {
        private let lock: NSLock = NSLock()
        private var records: [HealthRecord] = []

        func addRecord(_ record: HealthRecord) {
            lock.lock()
            defer { lock.unlock() }
            records.append(record)
        }

        func getRecords() -> [HealthRecord] {
            lock.lock()
            defer { lock.unlock() }
            return records
        }

        deinit {
            // Clean up if needed
        }
    }

    internal let definition: ToolDefinition = ToolDefinition(
        name: "health_data",
        description: "Retrieves health data from HealthKit",
        schema: """
        {
            "type": "object",
            "properties": {
                "metric": {
                    "type": "string",
                    "enum": ["steps", "distance", "calories", "heart_rate"],
                    "description": "The health metric to retrieve"
                },
                "date": {
                    "type": "string",
                    "description": "The date to retrieve data for (e.g., 'today', 'yesterday')"
                }
            },
            "required": ["metric", "date"]
        }
        """
    )

    private let executionHistoryStorage: ExecutionHistoryStorage = ExecutionHistoryStorage()

    internal var executionHistory: [HealthRecord] {
        executionHistoryStorage.getRecords()
    }

    deinit {
        // Clean up if needed
    }

    // swiftlint:disable:next async_without_await
    internal func execute(request: ToolRequest) async -> ToolResponse {
        guard let argumentData = request.arguments.data(using: .utf8),
            let arguments = try? JSONSerialization.jsonObject(
                with: argumentData,
                options: []
            ) as? [String: Any] else {
            return createErrorResponse(
                request: request,
                message: "Invalid JSON arguments",
                error: "Could not parse arguments as JSON"
            )
        }

        return processHealthRequest(request: request, arguments: arguments)
    }

    private func processHealthRequest(
        request: ToolRequest,
        arguments: [String: Any]
    ) -> ToolResponse {
        guard let params = extractParameters(arguments) else {
            return createErrorResponse(
                request: request,
                message: "Invalid arguments",
                error: "Missing or invalid required parameters"
            )
        }

        return retrieveHealthData(request: request, params: params)
    }

    private func extractParameters(_ arguments: [String: Any]) -> HealthParams? {
        guard let metric = arguments["metric"] as? String,
            let date = arguments["date"] as? String else {
            return nil
        }
        return HealthParams(metric: metric, date: date)
    }

    private func retrieveHealthData(
        request: ToolRequest,
        params: HealthParams
    ) -> ToolResponse {
        let (value, unit): (Double, String) = getHealthValue(
            metric: params.metric,
            params.date
        )

        return createSuccessResponse(
            request: request,
            params: params,
            value: value,
            unit: unit
        )
    }

    private func getHealthValue(metric: String, _: String) -> (Double, String) {
        switch metric.lowercased() {
        case "steps":
            return (Constants.mockStepsValue, "steps")

        case "distance":
            return (Constants.mockDistanceValue, "km")

        case "calories":
            return (Constants.mockCaloriesValue, "calories")

        case "heart_rate":
            return (Constants.mockHeartRateValue, "bpm")

        default:
            return (Constants.defaultValue, "unknown")
        }
    }

    private func createSuccessResponse(
        request: ToolRequest,
        params: HealthParams,
        value: Double,
        unit: String
    ) -> ToolResponse {
        let record: HealthRecord = HealthRecord(
            metric: params.metric,
            value: value,
            unit: unit,
            date: params.date
        )

        executionHistoryStorage.addRecord(record)

        let output: String = formatOutput(
            metric: params.metric,
            value: value,
            unit: unit,
            date: params.date
        )

        return ToolResponse(
            requestId: request.id,
            toolName: request.name,
            result: output
        )
    }

    private func createErrorResponse(
        request: ToolRequest,
        message: String,
        error: String
    ) -> ToolResponse {
        ToolResponse(
            requestId: request.id,
            toolName: request.name,
            result: "Error: \(message)",
            error: error
        )
    }

    private func formatOutput(
        metric: String,
        value: Double,
        unit: String,
        date: String
    ) -> String {
        """
        {
            "metric": "\(metric)",
            "value": \(value),
            "unit": "\(unit)",
            "date": "\(date)",
            "source": "HealthKit"
        }
        """
    }
}
