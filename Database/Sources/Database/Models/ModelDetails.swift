import Foundation
import SwiftData

/// Stores detailed documentation and large text fields for models
///
/// This entity is separated from the main Model entity to optimize performance
/// by keeping the primary Model entity lightweight for frequent queries.
/// Large text fields like model cards are loaded separately when needed.
@Model
public final class ModelDetails {
    // MARK: - Properties

    /// The detailed model card content from HuggingFace
    /// Can contain extensive markdown documentation about the model
    @Attribute()
    public internal(set) var modelCard: String?

    /// Additional notes or documentation added by the user
    @Attribute()
    public internal(set) var userNotes: String?

    /// Cached formatted model card for display (optional optimization)
    @Attribute()
    public internal(set) var formattedModelCard: String?

    // MARK: - Relationships

    /// The model this details entity belongs to
    public internal(set) var model: Model?

    // MARK: - Initialization

    init(
        modelCard: String? = nil,
        userNotes: String? = nil,
        formattedModelCard: String? = nil
    ) {
        self.modelCard = modelCard
        self.userNotes = userNotes
        self.formattedModelCard = formattedModelCard
    }

    /// Create ModelDetails from a model card string
    convenience init(modelCard: String?) {
        self.init(
            modelCard: modelCard,
            userNotes: nil,
            formattedModelCard: nil
        )
    }
}

// MARK: - Computed Properties

public extension ModelDetails {
    /// Returns the display-ready model card content
    var displayModelCard: String? {
        formattedModelCard ?? modelCard
    }

    /// Returns a summary of the model card (first 200 characters)
    var modelCardSummary: String? {
        guard let card = modelCard, !card.isEmpty else { return nil }

        let summary = String(card.prefix(200))
        return card.count > 200 ? summary + "..." : summary
    }

    /// Whether this details entity has any content
    var hasContent: Bool {
        !(modelCard?.isEmpty ?? true) ||
               !(userNotes?.isEmpty ?? true) ||
               !(formattedModelCard?.isEmpty ?? true)
    }
}
