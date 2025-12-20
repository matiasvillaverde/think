import Abstractions
import OSLog
import SQLiteVec

extension RagDatabase {
    /// Deletes all tables by effectively resetting the database
    func deleteAll() async throws {
        let deleteState: OSSignpostIntervalState = tracing.beginInterval("DeleteAll")
        logger.info("Deleting all tables")

        do {
            // Clear all indexes first
            tableIndexes.removeAll()

            // Get the current database location
            let location: String? = try await database.query("PRAGMA database_list").first?["file"] as? String
            logger.debug("Current database location: \(location ?? "unknown")")

            // Begin transaction
            try await database.execute("BEGIN IMMEDIATE")

            // Close all prepared statements and detach database
            try await database.execute("""
                PRAGMA writable_schema = 1;
                DELETE FROM sqlite_master WHERE type IN ('table', 'index', 'trigger');
                PRAGMA writable_schema = 0;
                VACUUM;
                PRAGMA integrity_check;
            """)

            // Re-initialize the database
            try await setupDatabase()

            try await database.execute("COMMIT")

            logger.notice("Successfully reset database and reinitialized schema")
            tracing.endInterval("DeleteAll", deleteState)
        } catch {
            logger.error("Failed to reset database: \(error.localizedDescription)")
            try await database.execute("ROLLBACK")
            tracing.emitEvent("Database reset failed")
            tracing.endInterval("DeleteAll", deleteState)
            throw Error.databaseError(error.localizedDescription)
        }
    }
}

// MARK: - Errors

extension RagDatabase {
    public enum Error: Swift.Error, LocalizedError, Equatable {
        case chunkNotFound
        case databaseError(String)
        case invalidTableName

        public var errorDescription: String? {
            switch self {
            case .chunkNotFound:
                return "The requested chunk was not found"

            case .databaseError(let details):
                return "Database error: \(details)"

            case .invalidTableName:
                return "Invalid table name"
            }
        }
    }
}
