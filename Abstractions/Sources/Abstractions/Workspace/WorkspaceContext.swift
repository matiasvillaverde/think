import Foundation

/// Represents workspace bootstrap context loaded from files.
public struct WorkspaceContext: Sendable, Equatable {
    /// Ordered sections loaded from workspace files.
    public let sections: [WorkspaceContextSection]

    /// Initialize a new workspace context.
    public init(sections: [WorkspaceContextSection]) {
        self.sections = sections
    }

    /// Returns true when no sections are available.
    public var isEmpty: Bool {
        sections.isEmpty
    }
}

/// A single workspace context section with a title and content.
public struct WorkspaceContextSection: Sendable, Equatable {
    public let title: String
    public let content: String

    public init(title: String, content: String) {
        self.title = title
        self.content = content
    }
}
