import Foundation
import Abstractions

// MARK: - ModelDTO
public struct ModelDTO: Decodable, Sendable {
    public let type: SendableModel.ModelType
    public let backend: SendableModel.Backend
    public let name: String
    let displayName: String
    let displayDescription: String
    let author: String?
    let license: String?
    let licenseUrl: String?
    let tags: [String]
    let downloads: Int
    let likes: Int
    let lastModified: Date?
    let skills: [String]
    let parameters: UInt64
    let ramNeeded: UInt64
    let size: UInt64
    let locationHuggingface: String
    let version: Int
    let architecture: Architecture

    public init(
        type: SendableModel.ModelType,
        backend: SendableModel.Backend,
        name: String,
        displayName: String,
        displayDescription: String,
        author: String? = nil,
        license: String? = nil,
        licenseUrl: String? = nil,
        tags: [String] = [],
        downloads: Int = 0,
        likes: Int = 0,
        lastModified: Date? = nil,
        skills: [String],
        parameters: UInt64,
        ramNeeded: UInt64,
        size: UInt64,
        locationHuggingface: String,
        version: Int,
        architecture: Architecture = .unknown
    ) {
        self.type = type
        self.backend = backend
        self.name = name
        self.displayName = displayName
        self.displayDescription = displayDescription
        self.author = author
        self.license = license
        self.licenseUrl = licenseUrl
        self.tags = tags
        self.downloads = downloads
        self.likes = likes
        self.lastModified = lastModified
        self.skills = skills
        self.parameters = parameters
        self.ramNeeded = ramNeeded
        self.size = size
        self.version = version
        self.locationHuggingface = locationHuggingface
        self.architecture = architecture
    }
}

// MARK: - Helper for Model Creation
extension ModelDTO {
    /// Convert DTO to Model initializer parameters
    func createModel() throws -> Model {
        try Model(
            type: type,
            backend: backend,
            name: name,
            displayName: displayName,
            displayDescription: displayDescription,
            author: author,
            license: license,
            licenseUrl: licenseUrl,
            tags: tags,
            downloads: downloads,
            likes: likes,
            lastModified: lastModified,
            skills: skills,
            parameters: parameters,
            ramNeeded: ramNeeded,
            size: size,
            locationHuggingface: locationHuggingface,
            version: version,
            architecture: architecture
        )
    }
}
