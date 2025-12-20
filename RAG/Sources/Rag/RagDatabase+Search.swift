import Abstractions
import OSLog
import SQLiteVec

extension RagDatabase {
    /// Performs a vector search across all tables in the database
    /// - Parameters:
    ///   - queryVector: The vector to search for
    ///   - limit: Maximum number of results to return per table
    ///   - threshold: Maximum distance threshold for matching results
    /// - Returns: Array of search results sorted by distance
    func performVectorSearchEverywhere(
        _ queryVector: [Float],
        limit: Int,
        threshold: Double
    ) async -> [SearchResult] {
        let searchState: OSSignpostIntervalState = tracing.beginInterval("VectorSearchEverywhere")
        logger.info("Performing vector search across all tables with limit \(limit) and threshold \(threshold)")

        var allResults: [SearchResult] = []
        // Get all tables from tableIndexes
        for tableName in tableIndexes.keys {
            logger.debug("Searching table: \(tableName)")

            do {
                let tableResults: [SearchResult] = try await performVectorSearch(
                    queryVector,
                    limit: limit,
                    threshold: threshold,
                    table: tableName
                )
                allResults.append(contentsOf: tableResults)
                logger.debug("Found \(tableResults.count) results in table \(tableName)")
            } catch {
                logger.error("Failed to search table \(tableName): \(error.localizedDescription)")
                // Continue with other tables even if one fails
                continue
            }
        }

        // Sort results by score across all tables
        let sortedResults: Array<SearchResult>.SubSequence = allResults
            .sorted { $0.score < $1.score }
            .prefix(limit)

        logger.info("Vector search everywhere completed. Total results: \(sortedResults.count)")
        tracing.endInterval("VectorSearchEverywhere", searchState)
        return Array(sortedResults)
    }

    /// Deletes all records associated with the specified UUID from a table
    /// - Parameters:
    ///   - id: The UUID of the records to delete
    ///   - table: The table to delete from (defaults to Abstractions.Constants.defaultTable)
    func delete(
        id: UUID,
        table: String = Abstractions.Constants.defaultTable
    ) async throws {
        let deleteState: OSSignpostIntervalState = tracing.beginInterval("Delete")
        logger.info("Deleting records for ID \(id) from table \(table)")

        do {
            guard isValidTableName(table) else {
                logger.error("Invalid table name: \(table)")
                throw Error.invalidTableName
            }

            // Begin transaction
            try await database.execute("BEGIN IMMEDIATE")

            let deleteSQL: String = """
            DELETE FROM \(table)
            WHERE id = ?
            """

            let result: Int = try await database.execute(deleteSQL, params: [id.uuidString])

            if result == 0 {
                logger.warning("No records found to delete for ID \(id)")
            } else {
                logger.notice("Successfully deleted \(result) records for ID \(id)")
            }

            try await database.execute("COMMIT")
            tracing.endInterval("Delete", deleteState)
        } catch {
            logger.error("Failed to delete records: \(error.localizedDescription)")
            try await database.execute("ROLLBACK")
            tracing.emitEvent("Delete failed")
            tracing.endInterval("Delete", deleteState)
            throw Error.databaseError(error.localizedDescription)
        }
    }

    /// Deletes a specific table from the database
    /// - Parameter table: The name of the table to delete
    func deleteTable(_ table: String = Abstractions.Constants.defaultTable) async throws {
        let deleteState: OSSignpostIntervalState = tracing.beginInterval("DeleteTable")
        logger.info("Deleting table \(table)")

        do {
            guard isValidTableName(table) else {
                logger.error("Invalid table name: \(table)")
                throw Error.invalidTableName
            }

            // Begin transaction
            try await database.execute("BEGIN IMMEDIATE")

            // Drop the table
            try await database.execute("DROP TABLE IF EXISTS \(table)")

            // Remove table from indexes
            tableIndexes.removeValue(forKey: table)

            try await database.execute("COMMIT")

            logger.notice("Successfully deleted table \(table)")
            tracing.endInterval("DeleteTable", deleteState)
        } catch {
            logger.error("Failed to delete table: \(error.localizedDescription)")
            try await database.execute("ROLLBACK")
            tracing.emitEvent("Delete table failed")
            tracing.endInterval("DeleteTable", deleteState)
            throw Error.databaseError(error.localizedDescription)
        }
    }
}
