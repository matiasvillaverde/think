import Foundation

public struct ModelToken: Identifiable, Hashable {
    public let displayName: String
    public var id: String { displayName }
}
