import Foundation
import PhotosUI
import SwiftUI

/// Protocol for managing personality editing operations
@preconcurrency
@MainActor
public protocol PersonalityEditViewModeling: Observable {
    // MARK: - Form Fields

    /// The name of the personality being edited
    var name: String { get set }

    /// The description of the personality
    var description: String { get set }

    /// The soul/identity of the personality (optional, can be empty)
    var soul: String { get set }

    /// The system instruction that defines the personality's behavior
    var systemInstruction: String { get set }

    /// The selected category for the personality
    var selectedCategory: PersonalityCategory { get set }

    /// The selected image item from PhotosPicker
    var selectedImage: PhotosPickerItem? { get set }

    // MARK: - State Management

    /// Indicates whether the personality data is currently loading
    var isLoading: Bool { get }

    /// Indicates whether the personality is currently being updated
    var isUpdating: Bool { get }

    /// Validation error message if any
    var validationError: String? { get }

    /// Flag to indicate the view should dismiss after successful update
    var shouldDismiss: Bool { get }

    /// Whether the personality can be deleted (only custom personalities)
    var isDeletable: Bool { get }

    // MARK: - Actions

    /// Loads the personality data from the database
    func loadPersonality() async

    /// Updates the personality with the current form data
    /// - Returns: True if update was successful, false otherwise
    func updatePersonality() async -> Bool

    /// Deletes the personality (only for custom personalities)
    /// - Returns: True if deletion was successful, false otherwise
    func deletePersonality() async -> Bool
}
