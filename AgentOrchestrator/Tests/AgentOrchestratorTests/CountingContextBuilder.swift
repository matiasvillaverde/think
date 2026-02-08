import Abstractions
import ContextBuilder
import Foundation

internal actor CountingContextBuilder: ContextBuilding {
    private let wrapped: ContextBuilder
    internal private(set) var processCallCount: Int = 0

    internal init(wrapping wrapped: ContextBuilder) {
        self.wrapped = wrapped
    }

    internal func build(parameters: BuildParameters) async throws -> String {
        try await wrapped.build(parameters: parameters)
    }

    internal func process(output: String, model: SendableModel) async throws -> ProcessedOutput {
        processCallCount += 1
        return try await wrapped.process(output: output, model: model)
    }

    internal func getStopSequences(model _: SendableModel) -> Set<String> {
        // Not needed for these tests; avoid cross-actor sync call.
        []
    }
}
