import Abstractions
import Foundation

/// Filter options for model types in the discovery view
public enum ModelTypeFilter: String, CaseIterable, Identifiable {
    case image = "img"
    case text = "txt"
    case visual = "vis"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .image:
            String(localized: "Image", bundle: .module)

        case .text:
            String(localized: "Text", bundle: .module)

        case .visual:
            String(localized: "Multimodal", bundle: .module)
        }
    }

    /// The icon name for this filter
    public var iconName: String {
        switch self {
        case .image:
            "photo"

        case .text:
            "text.alignleft"

        case .visual:
            "photo.on.rectangle"
        }
    }

    /// Gets the model types that match this filter
    public var modelTypes: [SendableModel.ModelType] {
        switch self {
        case .image:
            [.diffusion, .diffusionXL]

        case .text:
            [.language, .deepLanguage, .flexibleThinker]

        case .visual:
            [.visualLanguage]
        }
    }

    /// Checks if a model matches this filter
    @preconcurrency
    @MainActor
    public func matches(_ model: DiscoveredModel) -> Bool {
        guard let modelType = model.inferredModelType else {
            return false
        }
        return modelTypes.contains(modelType)
    }
}
