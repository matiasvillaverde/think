import Abstractions
import Embeddings
import OSLog
import SQLiteVec

/// An actor that provides thread-safe access to RAG database operations including vector storage and search
public final actor RagDatabase {
    // MARK: - Private Properties

    internal let database: Database
    internal let tracing: OSSignposter
    internal let logger: Logger
    internal var tableIndexes: [String: Int] = [:]
    internal let embeddingCache: EmbeddingCache

    // MARK: - Initialization

    /// Creates a new RagDatabase instance with the specified database location
    /// - Parameter database: The location where the database should be stored (defaults to in-memory)
    /// - Throws: Database initialization errors
    public init(
        database: DatabaseLocation = .inMemory
    ) async throws {
        let subsystem: String = "RAG"
        self.tracing = OSSignposter(subsystem: subsystem, category: "Rag")
        self.logger = Logger(subsystem: subsystem, category: "Rag")
        self.embeddingCache = EmbeddingCache(maxEntries: Constants.EmbeddingCache.defaultMaxEntries)

        logger.info("Initializing RagDatabase with location: \(database.debugDescription)")

        let initState: OSSignpostIntervalState = tracing.beginInterval("DatabaseInitialization")

        do {
            logger.debug("Initializing SQLiteVec")
            try SQLiteVec.initialize()

            switch database {
            case .inMemory:
                logger.debug("Creating in-memory database")
                self.database = try Database(.inMemory)

            case .temporary:
                logger.debug("Creating temporary database")
                self.database = try Database(.temporary)

            case .uri(let uri):
                logger.debug("Opening database at URI: \(uri)")
                self.database = try Database(.uri(uri))
            }

            // Setup database schema and initialize indexes
            try await setupDatabase()

            tracing.emitEvent("Database initialization complete")
            tracing.endInterval("DatabaseInitialization", initState)
            logger.notice("RagDatabase initialization successful")
        } catch {
            logger.error("Failed to initialize RagDatabase: \(error.localizedDescription)")
            tracing.emitEvent("Database initialization failed")
            tracing.endInterval("DatabaseInitialization", initState)
            throw error
        }
    }

    // MARK: - Public Methods

    func search(
        index: Int,
        table: String = Abstractions.Constants.defaultTable
    ) async throws -> SearchResult {
        let searchState: OSSignpostIntervalState = tracing.beginInterval("Search")
        logger.debug("Searching for index \(index) in table \(table)")

        do {
            guard isValidTableName(table) else {
                logger.error("Invalid table name: \(table)")
                throw Error.invalidTableName
            }

            let querySQL: String = """
            SELECT rowid, id, original_text, keywords
            FROM \(table)
            WHERE rowid = ?
            LIMIT 1
            """

            logger.trace("Executing query: \(querySQL) with index: \(index)")
            let rows: [[String: Any]] = try await database.query(querySQL, params: [index])

            guard let row = rows.first,
                let rowId = row["rowid"] as? Int,
                let originalText = row["original_text"] as? String,
                let keywords = row["keywords"] as? String,
                let id = row["id"] as? String,
                let uuid = UUID(uuidString: id)
            else {
                logger.error("Chunk not found for index: \(index)")
                throw Error.chunkNotFound
            }

            let result: SearchResult = SearchResult(
                id: uuid,
                text: originalText,
                keywords: keywords,
                score: 0.0,
                rowId: UInt(rowId)
            )

            logger.debug("Found result for index \(index): \(result.id)")
            tracing.endInterval("Search", searchState)
            return result
        } catch {
            logger.error("Search failed: \(error.localizedDescription)")
            tracing.emitEvent("Search failed")
            tracing.endInterval("Search", searchState)
            throw error
        }
    }

    func performVectorSearch(
        _ queryVector: [Float],
        limit: Int,
        threshold: Double,
        table: String = Abstractions.Constants.defaultTable
    ) async throws -> [SearchResult] {
        let searchState: OSSignpostIntervalState = tracing.beginInterval("VectorSearch")
        logger.debug("Performing vector search in table \(table) with limit \(limit) and threshold \(threshold)")

        do {
            guard isValidTableName(table) else {
                logger.error("Invalid table name: \(table)")
                throw Error.invalidTableName
            }

            tracing.emitEvent("Executing vector search query")
            let search: [[String: Any]] = try await database.query(
                """
                SELECT rowid, distance, id, original_text, keywords
                FROM \(table)
                WHERE embedding MATCH ?
                ORDER BY distance
                LIMIT ?
                """,
                params: [queryVector, limit]
            )

            let results: [SearchResult] = processSearchResults(search, threshold: threshold)
            logger.info("Vector search found \(results.count) results")

            tracing.endInterval("VectorSearch", searchState)
            return results
        } catch {
            logger.error("Vector search failed: \(error.localizedDescription)")
            tracing.emitEvent("Vector search failed")
            tracing.endInterval("VectorSearch", searchState)
            throw error
        }
    }

    // MARK: - Private Methods

    internal func setupDatabase() async throws {
        let setupState: OSSignpostIntervalState = tracing.beginInterval("SetupDatabase")
        logger.info("Setting up database schema")

        do {
            // Initialize the default table
            try await ensureTable(Abstractions.Constants.defaultTable)

            // Initialize indexes for all tables
            let tables: [[String: Any]] = try await database.query("""
                SELECT name FROM sqlite_master
                WHERE type='table' AND name GLOB '[a-zA-Z_]*'
            """)

            for table in tables {
                guard let tableName = table["name"] as? String else { continue }
                let maxIndex: Int = try await getMaxIndex(for: tableName)
                tableIndexes[tableName] = maxIndex + 1
                logger.debug("Initialized index for table \(tableName) starting at \(maxIndex + 1)")
            }

            logger.notice("Database schema setup complete")
            tracing.endInterval("SetupDatabase", setupState)
        } catch {
            logger.error("Failed to setup database: \(error.localizedDescription)")
            tracing.emitEvent("Database setup failed")
            tracing.endInterval("SetupDatabase", setupState)
            throw error
        }
    }

    internal func ensureTable(_ table: String) async throws {
        logger.debug("Ensuring table \(table) exists with correct schema")

        // Create table with vector storage format
        let createTableSQL: String = """
        CREATE VIRTUAL TABLE IF NOT EXISTS \(table) USING vec0(
            embedding FLOAT[\(Constants.embeddingDimension)],
            id TEXT NOT NULL,
            original_text TEXT NOT NULL,
            keywords TEXT NOT NULL
        )
        """

        try await database.execute(createTableSQL)
        logger.debug("Table \(table) created/verified")

        // Initialize index if needed
        if tableIndexes[table] == nil {
            let maxIndex: Int = try await getMaxIndex(for: table)
            tableIndexes[table] = maxIndex + 1
            logger.debug("Initialized index for table \(table) starting at \(maxIndex + 1)")
        }
    }

    private func getMaxIndex(for table: String) async throws -> Int {
        let result: [[String: Any]] = try await database.query("SELECT MAX(rowid) as max_id FROM \(table)")
        return result.first?["max_id"] as? Int ?? 0
    }

    internal func getNextIndex(for table: String, count: Int = 1) throws -> Int {
        guard let currentIndex = tableIndexes[table] else {
            throw Error.invalidTableName
        }

        let nextIndex: Int = currentIndex
        tableIndexes[table] = currentIndex + count

        logger.debug("Reserved \(count) indexes for table \(table) starting at \(nextIndex)")
        return nextIndex
    }

    internal func isValidTableName(_ table: String) -> Bool {
        let validTableNamePattern: Regex<Substring> = /^[a-zA-Z_][a-zA-Z0-9_]*$/
        let isValid: Bool = table.wholeMatch(of: validTableNamePattern) != nil
        if !isValid {
            logger.warning("Invalid table name detected: \(table)")
        }
        return isValid
    }

    private func processSearchResults(
        _ rows: [[String: Any]],
        threshold: Double,
        logger: Logger? = nil
    ) -> [SearchResult] {
        let processState: OSSignpostIntervalState = tracing.beginInterval("ProcessSearchResults")
        logger?.debug("Processing \(rows.count) search results with threshold \(threshold)")

        var results: [SearchResult] = []

        for row in rows {
            guard let rowId = row["rowid"] as? Int,
                let distance = row["distance"] as? Double,
                let id = row["id"] as? String,
                let originalText = row["original_text"] as? String,
                let keywords = row["keywords"] as? String,
                let uuid = UUID(uuidString: id),
                distance <= threshold
            else {
                logger?.debug("Discarding invalid or out-of-threshold result")
                continue
            }

            results.append(SearchResult(
                id: uuid,
                text: originalText,
                keywords: keywords,
                score: distance,
                rowId: UInt(rowId)
            ))
        }

        logger?.info("Processed \(results.count) valid results")
        tracing.endInterval("ProcessSearchResults", processState)
        return results
    }
}
