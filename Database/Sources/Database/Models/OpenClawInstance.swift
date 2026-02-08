import Foundation
import SwiftData

@Model
@DebugDescription
public final class OpenClawInstance: Identifiable, Equatable {
    @Attribute(.unique)
    public private(set) var id: UUID = UUID()

    @Attribute()
    public private(set) var createdAt: Date = Date()

    @Attribute()
    public internal(set) var updatedAt: Date = Date()

    @Attribute()
    public internal(set) var name: String

    /// Stored as a string for portability and easy validation.
    @Attribute()
    public internal(set) var urlString: String

    /// Optional bearer token for gateway auth.
    @Attribute()
    public internal(set) var authToken: String?

    init(
        name: String,
        urlString: String,
        authToken: String? = nil
    ) {
        self.name = name
        self.urlString = urlString
        self.authToken = authToken
    }
}

