import Abstractions
import Database
import Foundation
import OSLog
import PhotosUI
import SwiftUI

/// Actor responsible for managing personality creation in the UI layer
@preconcurrency
@MainActor
public final class PersonalityCreationViewModel: PersonalityCreationViewModeling, ObservableObject {
    // MARK: - Constants

    /// Kilobytes to bytes multiplier
    private static let bytesPerKilobyte: Int = 1_024

    /// Megabytes in 5MB limit
    private static let imageSizeLimitMegabytes: Int = 5

    /// Maximum allowed image size in bytes (5MB)
    private static let maxImageSizeBytes: Int = imageSizeLimitMegabytes * bytesPerKilobyte * bytesPerKilobyte

    /// Minimum system instruction length in characters
    private static let minSystemInstructionLength: Int = 10

    /// Maximum system instruction length in characters
    private static let maxSystemInstructionLength: Int = 5_000

    // MARK: - Published Properties

    @Published public var name: String = ""
    @Published public var description: String = ""
    @Published public var systemInstruction: String = ""
    @Published public var selectedCategory: PersonalityCategory = .productivity
    @Published public var selectedImage: PhotosPickerItem?
    @Published public var isCreating: Bool = false
    @Published public var validationError: String?
    @Published public var shouldDismiss: Bool = false
    @Published public private(set) var createdPersonalityId: UUID?

    // MARK: - Private Properties

    private let chatViewModel: ChatViewModeling
    private var imageData: Data?
    private let logger: Logger = Logger(subsystem: "ViewModels", category: "PersonalityCreationViewModel")
    private let maxImageSize: Int = PersonalityCreationViewModel.maxImageSizeBytes

    // MARK: - Initialization

    /// Initializes a new PersonalityCreationViewModel
    /// - Parameter chatViewModel: The chat view model for creating personalities
    public init(chatViewModel: ChatViewModeling) {
        self.chatViewModel = chatViewModel
        logger.info("PersonalityCreationViewModel initialized")
    }

    deinit {
        logger.info("PersonalityCreationViewModel deinitialized")
    }

    // MARK: - Public Methods

    /// Creates the personality with the current form data
    /// - Returns: True if creation was successful, false otherwise
    public func createPersonality() async -> Bool {
        logger.info("Starting personality creation")

        // Clear previous error
        validationError = nil

        // Validate form
        guard validateForm() else {
            logger.warning("Form validation failed: \(self.validationError ?? "Unknown error")")
            return false
        }

        // Handle image data from PhotosPickerItem
        if let selectedImage {
            do {
                logger.info("Loading image data from PhotosPickerItem")
                if let data = try await selectedImage.loadTransferable(type: Data.self) {
                    imageData = data
                    logger.info("Image data loaded successfully: \(data.count) bytes")
                }
            } catch {
                logger.error("Failed to load image data: \(error.localizedDescription)")
                validationError = "Failed to load image"
                return false
            }
        }

        // Start creation
        isCreating = true
        defer { isCreating = false }

        // Create personality
        let personalityId: UUID? = await chatViewModel.createPersonality(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            customSystemInstruction: systemInstruction.trimmingCharacters(in: .whitespacesAndNewlines),
            category: selectedCategory,
            customImage: imageData
        )

        if let personalityId {
            logger.info("Personality created successfully with ID: \(personalityId)")
            createdPersonalityId = personalityId
            shouldDismiss = true
            return true
        }

        logger.error("Failed to create personality")
        validationError = "Failed to create personality"
        return false
    }

    // MARK: - Private Methods

    private func validateForm() -> Bool {
        // Validate name
        let trimmedName: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            validationError = "Name cannot be empty"
            return false
        }

        // Validate description
        let trimmedDescription: String = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDescription.isEmpty {
            validationError = "Description cannot be empty"
            return false
        }

        // Validate system instruction
        let trimmedInstruction: String = systemInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedInstruction.count < Self.minSystemInstructionLength {
            validationError = "System instruction must be at least \(Self.minSystemInstructionLength) characters"
            return false
        }

        if trimmedInstruction.count > Self.maxSystemInstructionLength {
            validationError = "System instruction must be less than \(Self.maxSystemInstructionLength) characters"
            return false
        }

        // Validate image size
        if let imageData, imageData.count > maxImageSize {
            validationError = "Image size must be less than 5MB"
            return false
        }

        return true
    }

    // MARK: - Test Support Methods

    #if DEBUG
    /// Sets the name property (for testing)
    public func setName(_ newName: String) {
        name = newName
    }

    /// Sets the description property (for testing)
    public func setDescription(_ newDescription: String) {
        description = newDescription
    }

    /// Sets the system instruction property (for testing)
    public func setSystemInstruction(_ newInstruction: String) {
        systemInstruction = newInstruction
    }

    /// Sets the selected category (for testing)
    public func setSelectedCategory(_ category: PersonalityCategory) {
        selectedCategory = category
    }

    /// Sets the validation error (for testing)
    public func setValidationError(_ error: String?) {
        validationError = error
    }

    /// Sets the image data directly (for testing)
    public func setImageData(_ data: Data?) {
        imageData = data
    }
    #endif
}
