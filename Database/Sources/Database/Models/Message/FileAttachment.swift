import Foundation
import SwiftData
import OSLog

@Model
@DebugDescription
public final class FileAttachment: Identifiable, Equatable, ObservableObject {
    // MARK: - Identity

    /// A unique identifier for the entity.
    @Attribute(.unique)
    public private(set) var id: UUID = UUID()

    /// The creation date of the entity.
    @Attribute()
    public private(set)  var createdAt: Date = Date()

    // MARK: - Metadata

    @Attribute(.externalStorage, )
    public private(set) var file: Data

    @Attribute()
    public private(set) var name: String

    @Attribute()
    public private(set) var type: String // Extension

    @Attribute()
    public private(set) var summary: String?

    // MARK: - Relationships

    @Relationship(deleteRule: .nullify)
    public private(set) var message: Message?

    @Relationship(deleteRule: .nullify)
    public private(set) var chat: Chat?

    @Attribute()
    public internal(set) var ragState: State

    @Attribute()
    public internal(set) var progress: Double = 0

    /// Background task of RAG, we keep it here so it is possible to cancel it
    @Transient
    var backgroundTask: Task<Void, Error>?

    // MARK: - Initialized

    init(
        data: Data,
        chat: Chat,
        fileURL: URL,
        ragState: State = .saving
    ) throws {
        self.file = data
        self.name = fileURL.lastPathComponent
        self.type = fileURL.pathExtension
        self.summary = nil
        self.message = nil
        self.chat = chat
        self.ragState = ragState
        self.progress = 0
        backgroundTask = nil
    }

    convenience init(url: URL, chat: Chat) throws {
        // 1. Access the security-scoped resource (if sandboxed).
        guard url.startAccessingSecurityScopedResource() else {
            throw FileError.couldNotReadFile
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // 2. Read data from the file and convert into a String.
        let data = try Data(contentsOf: url)

        try self.init(data: data, chat: chat, fileURL: url)
    }
}

extension FileAttachment {
    public enum FileError: Swift.Error {
        case couldNotReadFile
        case messageOfDifferentChat
    }

    public enum State: String, Equatable, Codable {
        case saving
        case notStarted
        case saved
        case failed
    }
}

#if DEBUG
extension FileAttachment {
    @MainActor public static let preview: FileAttachment = {
        // swiftlint:disable:next force_try
        try! FileAttachment( // Preview data - error handling not needed in DEBUG
            data: Data(),
            chat: .preview,
            fileURL: URL(string: "Attention is all you need.pdf")!,
            ragState: .saving
        )
    }()

    @MainActor public static let previewsAllStates: [FileAttachment] = [
        // swiftlint:disable:next force_try
        try! FileAttachment( // Preview data - error handling not needed in DEBUG
            data: Data(),
            chat: .preview,
            fileURL: URL(string: "Attention is all you need.pdf")!,
            ragState: .saving
        ),
        // swiftlint:disable:next force_try
        try! FileAttachment( // Preview data - error handling not needed in DEBUG
            data: Data(),
            chat: .preview,
            fileURL: URL(string: "Attention is all you need.pdf")!,
            ragState: .notStarted
        ),
        // swiftlint:disable:next force_try
        try! FileAttachment( // Preview data - error handling not needed in DEBUG
            data: Data(),
            chat: .preview,
            fileURL: URL(string: "Attention is all you need.pdf")!,
            ragState: .saved
        ),
        // swiftlint:disable:next force_try
        try! FileAttachment( // Preview data - error handling not needed in DEBUG
            data: Data(),
            chat: .preview,
            fileURL: URL(string: "Attention is all you need.pdf")!,
            ragState: .failed
        )
    ]
}
#endif
