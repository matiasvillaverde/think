import Foundation

/// A type-erased async stream of agent events
public typealias AgentEventStream = AsyncStream<AgentEvent>

/// Protocol for objects that emit agent events during generation
public protocol AgentEventEmitting: Actor {
    /// The stream of events that can be observed
    var eventStream: AgentEventStream { get }
}
