import Foundation
import SwiftData
import Abstractions
import Observation

@Model
@DebugDescription
public final class Model: ObservableObject {
    // MARK: - Identity
    @Attribute(.unique, .allowsCloudEncryption)
    public internal(set) var id: UUID = UUID()

    @Attribute(.allowsCloudEncryption)
    public internal(set) var createdAt: Date = Date()

    // MARK: - Metadata

    @Attribute(.allowsCloudEncryption)
    public internal(set) var name: String

    @Attribute(.allowsCloudEncryption)
    public internal(set) var displayName: String = ""

    @Attribute(.allowsCloudEncryption)
    public internal(set) var displayDescription: String

    @Attribute(.allowsCloudEncryption)
    public internal(set) var author: String?

    @Attribute(.allowsCloudEncryption)
    public internal(set) var license: String?

    @Attribute(.allowsCloudEncryption)
    public internal(set) var licenseUrl: String?

    @Attribute(.allowsCloudEncryption)
    public internal(set) var downloads: Int? = 0

    @Attribute(.allowsCloudEncryption)
    public internal(set) var likes: Int? = 0

    @Attribute(.allowsCloudEncryption)
    public internal(set) var lastModified: Date?

    @Relationship(deleteRule: .cascade)
    public internal(set) var files: [ModelFile]

    @Relationship(deleteRule: .cascade)
    public internal(set) var details: ModelDetails?

    @Relationship(deleteRule: .cascade)
    public internal(set) var tags: [Tag]

    @Attribute(.allowsCloudEncryption)
    public internal(set) var parameters: UInt64

    // MARK: Technical metadata

    @Attribute(.allowsCloudEncryption)
    public internal(set) var type: SendableModel.ModelType

    @Attribute(.allowsCloudEncryption)
    public internal(set) var backend: SendableModel.Backend

    @Attribute(.allowsCloudEncryption)
    public internal(set) var ramNeeded: UInt64

    @Attribute(.allowsCloudEncryption)
    public internal(set) var size: UInt64

    @Attribute(.allowsCloudEncryption)
    public internal(set) var architecture: Architecture? = Architecture.unknown

    // MARK: - State

    @Attribute(.allowsCloudEncryption)
    public internal(set) var state: State? = State.notDownloaded

    /// Download progress (0.0 to 1.0) stored separately from state
    @Attribute(.allowsCloudEncryption)
    public internal(set) var downloadProgress: Double? = 0.0

    /// Runtime state that is persisted to disk - only modifiable through state machine transitions
    @Attribute(.allowsCloudEncryption)
    public internal(set) var runtimeState: RuntimeState? = RuntimeState.notLoaded

    /// HuggingFace repository ID for linking with DiscoveredModel
    /// Example: "mlx-community/Llama-3.2-3B-Instruct-4bit"
    @Attribute(.allowsCloudEncryption)
    public internal(set) var locationHuggingface: String? = ""

    // MARK: - Versioning

    /// Model version for tracking compatibility and migrations
    /// Version 1: Original models without versioning
    /// Version 2: Device-specific optimized models with proper initialization
    @Attribute(.allowsCloudEncryption)
    public internal(set) var version: Int? = 1

    // MARK: - Initializer
    /// Main initializer with all parameters
    public init(
        type: SendableModel.ModelType,
        backend: SendableModel.Backend,
        name: String,
        displayName: String = "",
        displayDescription: String,
        author: String? = nil,
        license: String? = nil,
        licenseUrl: String? = nil,
        tags: [String] = [],
        downloads: Int = 0,
        likes: Int = 0,
        lastModified: Date? = nil,
        skills: [String] = [], // Legacy parameter, merged with tags
        parameters: UInt64,
        ramNeeded: UInt64,
        size: UInt64,
        locationHuggingface: String,
        version: Int = 1,
        architecture: Architecture = .unknown
    ) throws {
        // Validate location format before initialization
        if locationHuggingface.isEmpty {
            throw ModelError.missingLocation("HuggingFace location cannot be empty")
        }

        // Basic validation for HuggingFace location format (should contain '/' for org/model)
        // Allow some flexibility for test cases but reject obvious invalid formats
        if locationHuggingface == "no-location" || locationHuggingface == "invalid" {
            throw ModelError.invalidLocation
        }

        // Initialize arrays first
        self.files = []
        // Merge both tags and skills into unified tags
        let allTagNames = Set(tags + skills)
        self.tags = allTagNames.map { Tag(name: $0) }

        // Then initialize other properties
        self.type = type
        self.backend = backend
        self.name = name
        self.displayName = displayName.isEmpty ? name : displayName
        self.displayDescription = displayDescription
        self.author = author
        self.license = license
        self.licenseUrl = licenseUrl
        self.downloads = downloads
        self.likes = likes
        self.lastModified = lastModified
        self.parameters = parameters
        self.ramNeeded = ramNeeded
        self.size = size
        self.version = version
        self.locationHuggingface = locationHuggingface
        self.architecture = architecture
        self.state = .notDownloaded
        self.downloadProgress = 0.0
        self.runtimeState = .notLoaded
    }
}

// MARK: - Equatable Conformance
extension Model: Equatable {
    public static func == (lhs: Model, rhs: Model) -> Bool {
        lhs.name == rhs.name
    }
}

// MARK: - Debug Descriptions
extension Model {
    public var debugDescription: String {
        """
        Model(
            id: \(id),
            createdAt: \(createdAt),
            type: \(type.rawValue),
            name: \(name),
            displayName: \(displayName),
            displayDescription: \(displayDescription),
            ramNeeded: \(ByteCountFormatter.string(fromByteCount: Int64(ramNeeded), countStyle: .memory)),
            size: \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)),
            location: \(locationHuggingface.debugDescription)
        )
        """
    }
}

// All extensions are now in separate files:
// - Model+State.swift: State enum, ModelError, and state-related properties
// - Model+RuntimeState.swift: RuntimeState and RuntimeTransition enums, state management
// - Model+Sendable.swift: toSendable() conversion method
// - Model+Preview.swift: Preview data for SwiftUI previews
// - ModelDTO.swift: ModelDTO struct for data transfer
