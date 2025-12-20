import Foundation
import SwiftData

@Model
public final class Tag: Comparable {
    // MARK: - Identity
    @Attribute()
    public internal(set) var id: UUID = UUID()

    @Attribute()
    public internal(set) var name: String

    // `.nullify` ensures that when a Model is deleted, this property is set to `nil` instead of creating conflicts
    @Relationship(deleteRule: .nullify)
    public private(set) var model: Model?

    init(name: String) {
        self.name = name
    }

    public static func < (lhs: Tag, rhs: Tag) -> Bool {
        lhs.name < rhs.name
    }
}
