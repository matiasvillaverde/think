import Abstractions
import Database
import Foundation
import OSLog
import PhotosUI
import SwiftUI

/// ViewModel responsible for managing personality editing in the UI layer
@preconcurrency
@MainActor
public final class PersonalityEditViewModel: PersonalityEditViewModeling, ObservableObject {
    // MARK: - Constants

    /// Kilobytes to bytes multiplier
    private static let bytesPerKilobyte: Int = 1_024

    /// Megabytes in 5MB limit
    private static let imageSizeLimitMegabytes: Int = 5

    /// Maximum allowed image size in bytes (5MB)
    private static let maxImageSizeBytes: Int = imageSizeLimitMegabytes * bytesPerKilobyte * bytesPerKilobyte

    // MARK: - Published Properties

    @Published public var name: String = ""
    @Published public var description: String = ""
    @Published public var soul: String = ""
    @Published public var systemInstruction: String = ""
    @Published public var selectedCategory: PersonalityCategory = .productivity
    @Published public var selectedImage: PhotosPickerItem?
    @Published public var isLoading: Bool = false
    @Published public var isUpdating: Bool = false
    @Published public var validationError: String?
    @Published public var shouldDismiss: Bool = false
    @Published public var isDeletable: Bool = false

    // MARK: - Private Properties

    private let database: DatabaseProtocol
    private let personalityId: UUID
    private var imageData: Data?
    private var originalSoul: String = ""
    private let logger: Logger = Logger(subsystem: "ViewModels", category: "PersonalityEditViewModel")
    private let maxImageSize: Int = PersonalityEditViewModel.maxImageSizeBytes

    // MARK: - Initialization

    /// Initializes a new PersonalityEditViewModel
    /// - Parameters:
    ///   - database: The database for persistence operations
    ///   - personalityId: The ID of the personality to edit
    public init(database: DatabaseProtocol, personalityId: UUID) {
        self.database = database
        self.personalityId = personalityId
        logger.info("PersonalityEditViewModel initialized for personality: \(personalityId)")
    }

    deinit {
        logger.info("PersonalityEditViewModel deinitialized")
    }

    // MARK: - Public Methods

    /// Loads the personality data from the database
    public func loadPersonality() async {
        logger.info("Loading personality data for ID: \(self.personalityId)")
        isLoading = true
        defer { isLoading = false }

        do {
            // Load personality data
            let personality: Personality = try await database.read(
                PersonalityCommands.Read(personalityId: personalityId)
            )

            // Populate form fields
            name = personality.name
            description = personality.displayDescription
            selectedCategory = personality.category
            isDeletable = personality.isDeletable

            // Load system instruction if custom
            if case .custom(let instruction) = personality.systemInstruction {
                systemInstruction = instruction
            }

            // Load soul from personality memory context
            await loadSoul()

            logger.info("Personality data loaded successfully")
        } catch {
            logger.error("Failed to load personality: \(error.localizedDescription)")
            validationError = String(localized: "Personality not found", bundle: .module)
        }
    }

    /// Updates the personality with the current form data
    /// - Returns: True if update was successful, false otherwise
    public func updatePersonality() async -> Bool {
        logger.info("Starting personality update")

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
                validationError = String(localized: "Failed to load image", bundle: .module)
                return false
            }
        }

        // Start update
        isUpdating = true
        defer { isUpdating = false }

        do {
            // Update personality
            _ = try await database.write(PersonalityCommands.Update(
                personalityId: personalityId,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                category: selectedCategory,
                customImage: imageData
            ))

            // Update soul if changed
            if soul != originalSoul {
                await updateSoul()
            }

            logger.info("Personality updated successfully")
            shouldDismiss = true
            return true
        } catch {
            logger.error("Failed to update personality: \(error.localizedDescription)")
            validationError = String(localized: "Failed to update personality", bundle: .module)
            return false
        }
    }

    /// Deletes the personality (only for custom personalities)
    /// - Returns: True if deletion was successful, false otherwise
    public func deletePersonality() async -> Bool {
        logger.info("Starting personality deletion")

        guard isDeletable else {
            logger.warning("Cannot delete system personality")
            validationError = String(localized: "System personalities cannot be deleted", bundle: .module)
            return false
        }

        isUpdating = true
        defer { isUpdating = false }

        do {
            _ = try await database.write(PersonalityCommands.Delete(personalityId: personalityId))
            logger.info("Personality deleted successfully")
            shouldDismiss = true
            return true
        } catch {
            logger.error("Failed to delete personality: \(error.localizedDescription)")
            validationError = String(localized: "Failed to delete personality", bundle: .module)
            return false
        }
    }

    // MARK: - Private Methods

    private func loadSoul() async {
        do {
            let memoryContext: MemoryContext = try await database.read(
                MemoryCommands.GetPersonalityMemoryContext(
                    personalityId: personalityId,
                    chatId: nil,
                    dailyLogDays: 0
                )
            )

            if let soulData: MemoryData = memoryContext.soul {
                soul = soulData.content
                originalSoul = soulData.content
            }
        } catch {
            logger.error("Failed to load soul: \(error.localizedDescription)")
        }
    }

    private func updateSoul() async {
        let trimmedSoul: String = soul.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSoul.isEmpty else {
            return
        }

        do {
            try await database.write(MemoryCommands.UpsertPersonalitySoul(
                personalityId: personalityId,
                content: trimmedSoul
            ))
            logger.info("Soul updated successfully")
        } catch {
            logger.error("Failed to update soul: \(error.localizedDescription)")
        }
    }

    private func validateForm() -> Bool {
        // Validate name
        let trimmedName: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            validationError = String(localized: "Name cannot be empty", bundle: .module)
            return false
        }

        // Validate description
        let trimmedDescription: String = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDescription.isEmpty {
            validationError = String(localized: "Description cannot be empty", bundle: .module)
            return false
        }

        // Validate image size
        if let imageData, imageData.count > maxImageSize {
            validationError = String(localized: "Image size must be less than 5MB", bundle: .module)
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

    /// Sets the soul property (for testing)
    public func setSoul(_ newSoul: String) {
        soul = newSoul
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
