import Foundation
import PhotosUI
import SwiftUI

/// Protocol for managing personality creation operations
@preconcurrency
@MainActor
public protocol PersonalityCreationViewModeling: Observable {
    // MARK: - Form Fields

    /// The name of the personality being created
    var name: String { get set }

    /// The description of the personality
    var description: String { get set }

    /// The system instruction that defines the personality's behavior
    var systemInstruction: String { get set }

    /// The selected category for the personality
    var selectedCategory: PersonalityCategory { get set }

    /// The selected image item from PhotosPicker
    var selectedImage: PhotosPickerItem? { get set }

    // MARK: - State Management

    /// Indicates whether the personality is currently being created
    var isCreating: Bool { get }

    /// Validation error message if any
    var validationError: String? { get }

    /// Flag to indicate the view should dismiss after successful creation
    var shouldDismiss: Bool { get }

    // MARK: - Actions

    /// Creates the personality with the current form data
    /// - Returns: True if creation was successful, false otherwise
    func createPersonality() async -> Bool
}
