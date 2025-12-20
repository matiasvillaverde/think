import SwiftData
import OSLog
import Abstractions

// MARK: - Type Aliases
typealias DatabaseResult<T> = Result<T, DatabaseError>
typealias CommandResult<T> = Result<T, Error>

// MARK: - ModelContext Extension
extension ModelContext {
    func getUser(id: PersistentIdentifier) throws -> User {
        guard let user = model(for: id) as? User else {
            throw DatabaseError.userNotFound
        }
        return user
    }

    func performFetch<T>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        do {
            return try fetch(descriptor)
        } catch {
            Logger.database.error("Failed to fetch: \(error.localizedDescription)")
            throw DatabaseError.fetchFailed(error as NSError)
        }
    }
}
