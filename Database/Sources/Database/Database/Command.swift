import Foundation
import Abstractions
import SwiftData

// MARK: - Command Protocols

public protocol UserCommand: Command {
    func execute(
        in context: ModelContext,
        user: User,
        rag: Ragging?
    ) throws -> Result
}

// MARK: - Protocol Extensions
public extension Command {
    var requiresUser: Bool { true }
    var requiresRag: Bool { false }
}

public extension AnonymousCommand {
    var requiresUser: Bool { false }

    func execute(
        in context: ModelContext,
        userId: PersistentIdentifier?,
        rag: Ragging?
    ) throws -> Result {
        try execute(in: context)
    }
}

public extension UserCommand {
    func execute(
        in context: ModelContext,
        userId: PersistentIdentifier?,
        rag: Ragging?
    ) throws -> Result {
        guard let userId else { throw DatabaseError.userNotFound }
        let user = try context.getUser(id: userId)
        return try execute(in: context, user: user, rag: rag)
    }
}
