import Abstractions
import Database
import Foundation

actor CLIAppBootstrapper {
    static let shared = CLIAppBootstrapper()

    private var initializedDatabaseID: ObjectIdentifier?
    private var inFlightTask: Task<Void, Error>?
    private var inFlightDatabaseID: ObjectIdentifier?

    func ensureInitialized(database: DatabaseProtocol) async throws {
        let databaseID = ObjectIdentifier(database as AnyObject)
        if initializedDatabaseID == databaseID {
            return
        }

        if let task = inFlightTask, inFlightDatabaseID == databaseID {
            try await task.value
            return
        }

        let task = Task {
            _ = try await database.execute(AppCommands.Initialize())
        }
        inFlightTask = task
        inFlightDatabaseID = databaseID

        do {
            try await task.value
            initializedDatabaseID = databaseID
            inFlightTask = nil
            inFlightDatabaseID = nil
        } catch {
            inFlightTask = nil
            inFlightDatabaseID = nil
            throw error
        }
    }
}
