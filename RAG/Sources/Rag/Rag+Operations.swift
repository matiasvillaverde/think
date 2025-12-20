import Abstractions
import Embeddings
import Foundation
import NaturalLanguage
import OSLog

extension Rag {
    /// Performs a semantic search across all tables in the database
    /// - Parameters:
    ///   - query: The search query string
    ///   - numResults: Maximum number of results to return per table
    ///   - threshold: Maximum distance threshold for matching results
    /// - Returns: Array of search results sorted by relevance
    public func semanticSearchEverywhere(
        query: String,
        numResults: Int,
        threshold: Double
    ) async throws -> [SearchResult] {
        let signpostID: OSSignpostID = tracing.makeSignpostID()
        let searchState: OSSignpostIntervalState = tracing.beginInterval("SemanticSearchEverywhere", id: signpostID)

        logger.info("Performing semantic search everywhere with query length: \(query.count, privacy: .public)")
        logger.debug(
            """
            Search parameters: numResults=\(numResults, privacy: .public), \
            threshold=\(threshold, privacy: .public)
            """
        )

        do {
            let encodingState: OSSignpostIntervalState = tracing.beginInterval("QueryEncoding", id: signpostID)
            let queryVector: [Float] = try await encodeQuery(query)
            tracing.endInterval("QueryEncoding", encodingState)
            logger.debug("Query encoded successfully")

            let vectorSearchState: OSSignpostIntervalState = tracing.beginInterval("VectorSearchEverywhere", id: signpostID)
            let results: [SearchResult] = try await database.performVectorSearchEverywhere(
                queryVector,
                limit: numResults,
                threshold: threshold
            )
            tracing.endInterval("VectorSearchEverywhere", vectorSearchState)

            logger.notice("Search everywhere completed successfully with \(results.count, privacy: .public) results")
            tracing.endInterval("SemanticSearchEverywhere", searchState)
            return results
        } catch {
            logger.error("Search everywhere failed: \(error, privacy: .public)")
            tracing.endInterval("SemanticSearchEverywhere", searchState)
            throw error
        }
    }

    /// Deletes all records associated with the specified UUID from a table
    /// - Parameters:
    ///   - id: The UUID of the records to delete
    ///   - table: The table to delete from (defaults to Abstractions.Constants.defaultTable)
    public func delete(
        id: UUID,
        table: String = Abstractions.Constants.defaultTable
    ) async throws {
        let signpostID: OSSignpostID = tracing.makeSignpostID()
        let deleteState: OSSignpostIntervalState = tracing.beginInterval("Delete", id: signpostID)

        logger.info("Deleting records for ID: \(id, privacy: .private) from table: \(table, privacy: .public)")

        do {
            try await database.delete(id: id, table: table)
            logger.notice("Successfully deleted records for ID: \(id, privacy: .private)")
            tracing.endInterval("Delete", deleteState)
        } catch {
            logger.error("Failed to delete records: \(error, privacy: .public)")
            tracing.endInterval("Delete", deleteState)
            throw error
        }
    }

    /// Deletes a specific table from the database
    /// - Parameter table: The name of the table to delete
    public func deleteTable(
        _ table: String = Abstractions.Constants.defaultTable
    ) async throws {
        let signpostID: OSSignpostID = tracing.makeSignpostID()
        let deleteState: OSSignpostIntervalState = tracing.beginInterval("DeleteTable", id: signpostID)

        logger.info("Deleting table: \(table, privacy: .public)")

        do {
            try await database.deleteTable(table)
            logger.notice("Successfully deleted table: \(table, privacy: .public)")
            tracing.endInterval("DeleteTable", deleteState)
        } catch {
            logger.error("Failed to delete table: \(error, privacy: .public)")
            tracing.endInterval("DeleteTable", deleteState)
            throw error
        }
    }

    /// Deletes all tables from the database
    public func deleteAll() async throws {
        let signpostID: OSSignpostID = tracing.makeSignpostID()
        let deleteState: OSSignpostIntervalState = tracing.beginInterval("DeleteAll", id: signpostID)

        logger.info("Deleting all tables")

        do {
            try await database.deleteAll()
            logger.notice("Successfully deleted all tables")
            tracing.endInterval("DeleteAll", deleteState)
        } catch {
            logger.error("Failed to delete all tables: \(error, privacy: .public)")
            tracing.endInterval("DeleteAll", deleteState)
            throw error
        }
    }

    // MARK: - Private Processing Methods

    internal func processFileInternal(
        fileURL: URL,
        id: UUID,
        configuration: Configuration,
        continuation: AsyncThrowingStream<Progress, Error>.Continuation
    ) async throws {
        let signpostID: OSSignpostID = tracing.makeSignpostID()
        let addFileState: OSSignpostIntervalState = tracing.beginInterval("AddFile", id: signpostID)

        let clock: ContinuousClock = ContinuousClock()
        let start: ContinuousClock.Instant = clock.now

        // Log the initiation of file processing with file details.
        logger.info(
            "Processing file: \(fileURL.lastPathComponent, privacy: .private), id: \(id, privacy: .private)"
        )
        logger.debug(
            "Configuration: tokenUnit=\(String(describing: configuration.tokenUnit), privacy: .public)"
        )
        logger.debug("Strategy: \(configuration.strategy.debugDescription, privacy: .public)")

        // Check if the file type is supported.
        guard let fileType: SupportedFileType = SupportedFileType.detect(from: fileURL) else {
            logger.error("Unsupported file type for: \(fileURL.lastPathComponent, privacy: .private)")
            tracing.endInterval("AddFile", addFileState)
            throw RagError.unsupportedFileType
        }

        logger.debug("Detected file type: \(fileType.debugDescription)")

        defer {
            tracing.endInterval("AddFile", addFileState)
        }

        let fileProcessingState: OSSignpostIntervalState = tracing.beginInterval("FileProcessing", id: signpostID)

        // Process the file asynchronously, yielding progress for each chunk.
        for try await chunk in try FileProcessor().processFile(
            fileURL,
            fileType: fileType,
            tokenUnit: configuration.tokenUnit,
            chunking: configuration.chunking,
            strategy: configuration.strategy
        ) {
            tracing.emitEvent("FileChunkProcessed", id: signpostID)

            if chunk.0.isEmpty {
                continuation.yield(chunk.1)
                continue
            }

            try await database.storeChunks(
                chunk.0,
                from: id,
                modelConfig: modelConfig,
                modelCache: modelCache,
                table: configuration.table
            )

            tracing.emitEvent("ChunkProcessed", id: signpostID)

            // Yield the progress update.
            continuation.yield(chunk.1)
        }

        // End the file processing interval.
        tracing.endInterval("FileProcessing", fileProcessingState)

        // Log the total processing time.
        logger.info("File loaded in \(clock.now.duration(to: start).abs)")
    }

    internal func processTextInternal(
        text: String,
        id: UUID,
        configuration: Configuration,
        continuation: AsyncThrowingStream<Progress, Error>.Continuation
    ) async throws {
        let signpostID: OSSignpostID = tracing.makeSignpostID()
        let addTextState: OSSignpostIntervalState = tracing.beginInterval("AddText", id: signpostID)

        // Optionally, record the start time.
        let clock: ContinuousClock = ContinuousClock()
        let start: ContinuousClock.Instant = clock.now

        logger.info(
            "Processing text with length: \(text.count, privacy: .public), id: \(id, privacy: .private)"
        )
        logger.debug(
            "Configuration: tokenUnit=\(String(describing: configuration.tokenUnit), privacy: .public)"
        )
        logger.debug("Strategy: \(configuration.strategy.debugDescription, privacy: .public)")

        defer {
            tracing.endInterval("AddText", addTextState)
        }

        // Process the text asynchronously, yielding progress updates for each chunk.
        for try await chunk in FileProcessor().processTextAsync(
            text,
            tokenUnit: configuration.tokenUnit,
            chunking: configuration.chunking,
            strategy: configuration.strategy
        ) {
            // Optionally emit tracing events before and after storing the chunk.
            tracing.emitEvent("TextChunkProcessed", id: signpostID)

            if chunk.0.isEmpty {
                continuation.yield(chunk.1)
                continue
            }

            try await database.storeChunks(
                chunk.0,
                from: id,
                modelConfig: modelConfig,
                modelCache: modelCache,
                table: configuration.table
            )

            tracing.emitEvent("ChunkProcessed", id: signpostID)

            // Yield the progress update.
            continuation.yield(chunk.1)
        }

        logger.info("Text processed in \(clock.now.duration(to: start).abs)")
    }
}
