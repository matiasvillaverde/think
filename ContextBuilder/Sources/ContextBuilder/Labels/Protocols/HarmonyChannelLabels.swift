import Foundation

/// Labels for Harmony channel system
internal protocol HarmonyChannelLabels {
    /// Analysis channel identifier
    var analysisChannel: String? { get }

    /// Final channel identifier
    var finalChannel: String? { get }

    /// Commentary channel identifier
    var commentaryChannel: String? { get }

    /// Developer role label
    var developerLabel: String? { get }
}
