import Abstractions
import Foundation
import SwiftData

/// Tool execution entity (Aggregate Root)
@Model
@DebugDescription
public final class ToolExecution: Identifiable, Equatable, ObservableObject {
    // MARK: - Identity
    
    @Attribute(.unique)
    public private(set) var id: UUID = UUID()
    
    @Attribute()
    public private(set) var createdAt: Date = Date()
    
    // MARK: - Tool Request (Immutable)
    
    /// The original tool request from the LLM (JSON string)
    @Attribute()
    public private(set) var requestJSON: String
    
    /// Tool name for quick lookup
    @Attribute()
    public private(set) var toolName: String
    
    // MARK: - Execution State
    
    @Attribute()
    public private(set) var state: ToolExecutionState
    
    // MARK: - Tool Response (Optional)
    
    /// The response data after execution (JSON string)
    @Attribute()
    public private(set) var responseJSON: String?
    
    /// Error message if execution failed
    @Attribute()
    public private(set) var errorMessage: String?
    
    // MARK: - Timestamps
    
    @Attribute()
    public private(set) var startedAt: Date?
    
    @Attribute()
    public private(set) var executedAt: Date?
    
    @Attribute()
    public private(set) var completedAt: Date?
    
    // MARK: - Relationships
    
    @Relationship
    public private(set) var channel: Channel?
    
    @Relationship(deleteRule: .cascade, inverse: \Source.toolExecution)
    public internal(set) var sources: [Source]?
    
    // MARK: - Computed Properties
    
    /// Decode the request from JSON string
    public var request: ToolRequest? {
        guard let data = requestJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ToolRequest.self, from: data)
    }
    
    /// Decode the response from JSON string
    public var response: ToolResponse? {
        guard let responseJSON else { return nil }
        guard let data = responseJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ToolResponse.self, from: data)
    }
    
    // MARK: - Initializers
    
    public init(
        request: ToolRequest,
        state: ToolExecutionState = .pending,
        channel: Channel? = nil
    ) {
        self.id = request.id
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        self.requestJSON = (try? String(data: encoder.encode(request), encoding: .utf8)) ?? "{}"
        self.toolName = request.name
        self.state = state
        self.channel = channel
    }
    
    // MARK: - State Management
    
    /// Transition to a new state with validation
    public func transitionTo(_ newState: ToolExecutionState) throws {
        guard isValidTransition(from: state, to: newState) else {
            throw ToolExecutionError.invalidStateTransition(from: state, to: newState)
        }
        
        state = newState
        
        switch newState {
        case .executing:
            startedAt = Date()
            executedAt = Date()
        case .completed, .failed:
            completedAt = Date()
        default:
            break
        }
    }
    
    /// Complete the execution with a response
    public func complete(with response: ToolResponse) throws {
        guard state == .executing else {
            throw ToolExecutionError.cannotCompleteInState(state)
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        self.responseJSON = try String(data: encoder.encode(response), encoding: .utf8)
        self.errorMessage = response.error
        
        if response.isError {
            try transitionTo(.failed)
        } else {
            try transitionTo(.completed)
        }
    }
    
    /// Mark execution as failed with an error
    public func fail(with error: String) throws {
        self.errorMessage = error
        
        // Create error response
        if let request = self.request {
            let errorResponse = ToolResponse(
                requestId: request.id,
                toolName: request.name,
                result: "Error: \(error)",
                error: error
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            self.responseJSON = try String(data: encoder.encode(errorResponse), encoding: .utf8)
        }
        
        try transitionTo(.failed)
    }
    
    // MARK: - Private Methods
    
    private func isValidTransition(
        from currentState: ToolExecutionState,
        to newState: ToolExecutionState
    ) -> Bool {
        switch (currentState, newState) {
        case (.parsing, .pending),
             (.parsing, .failed),
             (.pending, .executing),
             (.pending, .failed),
             (.executing, .completed),
             (.executing, .failed):
            return true
        default:
            return false
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension ToolExecution {
    @MainActor
    public static var preview: ToolExecution {
        let request = ToolRequest(
            name: "web_search",
            arguments: """
            {
                "query": "SwiftData relationships",
                "limit": 10
            }
            """,
            displayName: "Web Search"
        )
        
        let execution = ToolExecution(
            request: request,
            state: .completed
        )
        
        let response = ToolResponse(
            requestId: request.id,
            toolName: request.name,
            result: "Found 10 results about SwiftData relationships"
        )
        
        try? execution.complete(with: response)
        
        return execution
    }
    
    @MainActor
    public static var previewExecuting: ToolExecution {
        let request = ToolRequest(
            name: "analyze_code",
            arguments: """
            {
                "file": "ContentView.swift"
            }
            """,
            displayName: "Code Analysis"
        )
        
        return ToolExecution(
            request: request,
            state: .executing
        )
    }
    
    @MainActor
    public static var previewFailed: ToolExecution {
        let request = ToolRequest(
            name: "fetch_data",
            arguments: """
            {
                "url": "https://api.example.com/data"
            }
            """,
            displayName: "Fetch Data"
        )
        
        let execution = ToolExecution(
            request: request,
            state: .failed
        )
        execution.errorMessage = "Network connection failed"
        
        return execution
    }
}
#endif