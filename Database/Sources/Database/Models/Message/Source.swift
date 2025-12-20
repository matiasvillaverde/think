import SwiftUI
import SwiftData

@Model
@DebugDescription
public final class Source: Identifiable, Equatable, ObservableObject {
    // MARK: - Identity

    /// A unique identifier for the entity.
    @Attribute()
    public private(set) var id: UUID = UUID()

    // MARK: - Properties

    /// The URL of the source
    @Attribute()
    public private(set) var url: URL

    /// A display name for the source
    @Attribute()
    public private(set) var displayName: String

    // MARK: - Relationships

    @Relationship(deleteRule: .nullify)
    public private(set) var toolExecution: ToolExecution?

    // MARK: - Initializers

    init(
        url: URL,
        displayName: String,
        toolExecution: ToolExecution? = nil
    ) {
        self.url = url
        self.displayName = displayName
        self.toolExecution = toolExecution
    }
}
