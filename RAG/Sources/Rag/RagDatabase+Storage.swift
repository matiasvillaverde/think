import Abstractions
import CoreML
import Embeddings
import OSLog
import SQLiteVec

extension RagDatabase {
    /// Stores chunks in the database with proper synchronization
    func storeChunks(
        _ chunks: [ChunkData],
        from id: UUID,
        modelConfig: ModelConfiguration,
        modelCache: any RagModelCaching,
        table: String = Abstractions.Constants.defaultTable
    ) async throws {
        let storeState: OSSignpostIntervalState = tracing.beginInterval("StoreChunks")
        logger.info("Storing \(chunks.count) chunks for ID \(id) in table \(table)")

        do {
            guard isValidTableName(table) else {
                logger.error("Invalid table name: \(table)")
                throw Error.invalidTableName
            }

            try await ensureTable(table)
            if chunks.isEmpty {
                logger.notice("Skipping storage for empty chunk set in table \(table)")
                tracing.endInterval("StoreChunks", storeState)
                return
            }
            let embeddings: [[Float]] = try await encodeChunksForStorage(
                chunks,
                modelConfig: modelConfig,
                modelCache: modelCache
            )
            try await performBatchInsert(chunks: chunks, embeddings: embeddings, id: id, table: table)

            logger.notice("Successfully stored \(chunks.count) chunks")
            tracing.endInterval("StoreChunks", storeState)
        } catch {
            logger.error("Failed to store chunks: \(error.localizedDescription)")
            tracing.emitEvent("Store chunks failed")
            tracing.endInterval("StoreChunks", storeState)
            throw Error.databaseError(error.localizedDescription)
        }
    }

    private func encodeChunksForStorage(
        _ chunks: [ChunkData],
        modelConfig: ModelConfiguration,
        modelCache: any RagModelCaching
    ) async throws -> [[Float]] {
        tracing.emitEvent("Encoding chunks")
        let texts: [String] = chunks.map(\.text)
        let embeddings: [[Float]] = try await embeddingCache.embeddings(
            texts: texts,
            modelKey: modelConfig.cacheKey
        ) { [modelConfig] (texts: [String]) in
            let model: Bert.ModelBundle = try await modelCache.model(for: modelConfig)
            let encoded: MLTensor = try model.batchEncode(texts)
            return try await encoded.convertTensorToVectors()
        }

        guard embeddings.count == chunks.count else {
            logger.fault(
                "Embedding count mismatch: expected \(chunks.count), got \(embeddings.count)"
            )
            throw Error.databaseError("Embedding count mismatch")
        }

        guard let firstEmbedding = embeddings.first,
            firstEmbedding.count == Constants.embeddingDimension else {
            logger.fault(
                """
                Embedding dimension mismatch: expected \(Constants.embeddingDimension), \
                got \(embeddings.first?.count ?? 0)
                """
            )
            throw Error.databaseError("Embedding dimension mismatch")
        }

        return embeddings
    }

    private func performBatchInsert(
        chunks: [ChunkData],
        embeddings: [[Float]],
        id: UUID,
        table: String
    ) async throws {
        try await database.execute("BEGIN IMMEDIATE")

        do {
            let startIndex: Int = try getNextIndex(for: table, count: chunks.count)
            logger.debug("Beginning batch vector insertion")

            let singleValuePlaceholder: String = "(?, ?, ?, ?, ?)"
            let valuePlaceholders: String = (0..<chunks.count)
                .map { _ in singleValuePlaceholder }
                .joined(separator: ",")

            let batchQuery: String = """
                INSERT INTO \(table)(
                    rowid,
                    embedding,
                    id,
                    original_text,
                    keywords
                ) VALUES \(valuePlaceholders)
            """

            var params: [any Sendable] = []
            for (offset, chunk) in chunks.enumerated() {
                params.append(startIndex + offset)
                params.append(embeddings[offset])
                params.append(id.uuidString)
                params.append(chunk.text)
                params.append(chunk.keywords)
            }

            try await database.execute(batchQuery, params: params)
            try await database.execute("COMMIT")
            logger.debug("Batch insertion completed successfully")
        } catch {
            try await database.execute("ROLLBACK")
            throw error
        }
    }
}
