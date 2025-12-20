import Foundation

/// Protocol for generating placeholder images
internal protocol PlaceholderImageGenerating: Sendable {
    /// Generates placeholder image data
    func generatePlaceholderData() -> Data?
}
