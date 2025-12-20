import Foundation

/// Labels for Harmony-specific tokens
internal protocol HarmonyTokenLabels {
    /// Start token for Harmony format
    var startToken: String? { get }

    /// Message token
    var messageToken: String? { get }

    /// Channel token
    var channelToken: String? { get }

    /// Call token
    var callToken: String? { get }

    /// Return token
    var returnToken: String? { get }

    /// Constrain token
    var constrainToken: String? { get }
}
