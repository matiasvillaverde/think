// Personality.swift
import Abstractions
import Combine
import DataAssets
import Foundation
import SwiftData

/// Represents a personality configuration that combines system instructions with UI metadata
@Model
@DebugDescription
public final class Personality: Identifiable, Equatable, ObservableObject {
    // MARK: - Identity

    @Attribute(.unique)
    public private(set) var id: UUID = UUID()

    @Attribute()
    public private(set) var createdAt: Date = Date()

    // MARK: - Core Properties

    @Attribute()
    public internal(set) var name: String

    @Attribute()
    public internal(set) var displayDescription: String

    @Attribute()
    public internal(set) var systemInstruction: SystemInstruction

    @Attribute()
    public internal(set) var category: PersonalityCategory

    // MARK: - Visual Properties

    /// Image name for bundled/system images (e.g., "think")
    @Attribute()
    public internal(set) var imageName: String?

    @Attribute()
    public internal(set) var image: Data?

    /// Custom image attachment for user-created personalities
    @Relationship(deleteRule: .cascade)
    public internal(set) var customImage: ImageAttachment?

    /// Tint color stored as hex string for consistency
    @Attribute()
    public internal(set) var tintColorHex: String?

    /// If is feature
    @Attribute()
    public private(set) var isFeature: Bool

    /// Whether this is a user-created personality (false for system personalities)
    @Attribute()
    public private(set) var isCustom: Bool

    /// Is the main personality
    @Attribute()
    public private(set) var isDefault: Bool

    // MARK: - Content

    @Relationship(deleteRule: .cascade, inverse: \Prompt.personality)
    public internal(set) var prompts: [Prompt] = []

    // MARK: - Relationships

    /// Owner of the personality (nil for system personalities)
    @Relationship(deleteRule: .nullify)
    public private(set) var user: User?

    /// Memories associated with this personality (cascade delete when personality is deleted)
    @Relationship(deleteRule: .cascade, inverse: \Memory.personality)
    public internal(set) var memories: [Memory] = []

    /// The chat associated with this personality (1:1 relationship, cascade delete)
    @Relationship(deleteRule: .cascade, inverse: \Chat.personality)
    public internal(set) var chat: Chat?

    // MARK: - Computed Properties

    /// Returns the appropriate image for display
    public var displayImage: ImageAttachment? {
        customImage
    }

    /// Returns the soul memory associated with this personality (first soul-type memory)
    public var soul: Memory? {
        memories.first { $0.type == .soul }
    }

    /// Whether this personality has any conversation messages
    public var hasConversation: Bool {
        guard let chat else { return false }
        return !chat.messages.isEmpty
    }

    /// The date of the last message in this personality's conversation
    public var lastMessageDate: Date? {
        chat?.messages.last?.createdAt
    }

    /// The date to use for sorting - last message date or creation date
    public var sortDate: Date {
        lastMessageDate ?? createdAt
    }

    /// Whether this personality can be edited (all personalities are now editable)
    public var isEditable: Bool {
        true
    }

    /// Whether this personality can be deleted (only custom personalities can be deleted)
    public var isDeletable: Bool {
        isCustom
    }

    // MARK: - Initializers

    /// Creates a system personality (non-editable)
    public init(
        systemInstruction: SystemInstruction,
        name: String,
        description: String,
        imageName: String? = nil,
        category: PersonalityCategory,
        tintColorHex: String? = nil,
        prompts: [Prompt] = [],
        image: Data? = nil,
        isFeature: Bool = false,
        isDefault: Bool = false,
        isCustom: Bool = false,
        user: User? = nil
    ) {
        self.systemInstruction = systemInstruction
        self.name = name
        self.displayDescription = description
        self.imageName = imageName
        self.image = image
        self.category = category
        self.tintColorHex = tintColorHex
        self.prompts = prompts
        self.user = user
        self.isCustom = isCustom
        self.isFeature = isFeature
        self.isDefault = isDefault
    }

    // MARK: - Static Methods

    /// Default system personality
    public static var `default`: Personality {
        Personality(
            systemInstruction: .empatheticFriend,
            name: "Buddy",
            description: "A good buddy: upbeat, loyal, and real with you",
            imageName: "friend-icon",
            category: .personal,
            isDefault: true
        )
    }
    
    /// Safely finds or creates a system personality, preventing duplicates
    /// - Parameters:
    ///   - name: The name of the personality
    ///   - context: The ModelContext to search in
    /// - Returns: Existing personality if found, nil if should create new one
    /// - Throws: Database errors during fetch
    public static func findExistingSystemPersonality(
        name: String,
        in context: ModelContext
    ) throws -> Personality? {
        let descriptor = FetchDescriptor<Personality>(
            predicate: #Predicate<Personality> { 
                $0.name == name && !$0.isCustom 
            }
        )
        
        return try context.fetch(descriptor).first
    }
    
    /// Validates that no duplicate system personalities exist for the same name
    /// - Parameters:
    ///   - name: The name to check
    ///   - context: The ModelContext to search in
    /// - Throws: PersonalityError.duplicateSystemPersonality if duplicates found
    public static func validateNoDuplicateSystemPersonalities(
        name: String,
        in context: ModelContext
    ) throws {
        let descriptor = FetchDescriptor<Personality>(
            predicate: #Predicate<Personality> { 
                $0.name == name && !$0.isCustom 
            }
        )
        
        let existing = try context.fetch(descriptor)
        if existing.count > 1 {
            throw PersonalityError.duplicateSystemPersonality(name: name, count: existing.count)
        }
    }
}

// MARK: - Errors

public enum PersonalityError: Error {
    case cannotEditSystemPersonality
    case invalidSystemInstruction
    case invalidCategory
    case duplicateSystemPersonality(name: String, count: Int)
}

// MARK: - Filter Options

/// Filter options for personality list
public enum PersonalityFilterMode: CaseIterable {
    case all
    case system
    case custom
    case creative
    case productivity

    public var displayName: String {
        switch self {
        case .all:
            return String(localized: "All", bundle: .module)
        case .system:
            return String(localized: "System", bundle: .module)
        case .custom:
            return String(localized: "Custom", bundle: .module)
        case .productivity:
            return String(localized: "Productivity", bundle: .module)
        case .creative:
            return String(localized: "Creative", bundle: .module)
        }
    }
}

#if DEBUG
extension Personality {
    @MainActor public static var preview: Personality {
        Personality.default
    }

    @MainActor public static var previewCustom: Personality {
        Personality(
            systemInstruction: .creativeWritingCouch,
            name: "My Creative Assistant",
            description: "A customized creative writing helper",
            category: .creative
        )
    }
}
#endif
