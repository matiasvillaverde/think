import Foundation

/// Modes for steering/interrupting agent generation
public enum SteeringMode: Sendable, Equatable {
    /// Normal operation - no steering active
    case inactive

    /// Complete current tool execution, then stop
    case softInterrupt

    /// Immediate stop - cancel everything
    case hardStop

    /// Inject a new message and skip remaining tools
    case redirect(String)
}
