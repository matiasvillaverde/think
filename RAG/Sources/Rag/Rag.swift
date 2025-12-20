import Abstractions
import CoreML
import Embeddings
import Foundation
import NaturalLanguage
import OSLog

public final actor Rag: Ragging {
    // MARK: - Properties

    internal let tracing: OSSignposter = OSSignposter(subsystem: "RAG", category: "Rag")
    internal let logger: Logger = Logger(subsystem: "RAG", category: "Rag")
    internal let modelConfig: ModelConfiguration
    private let loadingStrategy: RagLoadingStrategy
    private var _model: Bert.ModelBundle?
    internal let modelCache: any RagModelCaching
    internal let database: RagDatabase

    // MARK: - Initialization

    public init(
        from hubRepoId: String = "sentence-transformers/all-MiniLM-L6-v2",
        local: URL? = nil,
        useBackgroundSession: Bool = false,
        database: DatabaseLocation = .inMemory,
        loadingStrategy: RagLoadingStrategy = .lazy
    ) async throws {
        logger.notice("Initializing Rag actor with configuration: hubRepoId=\(hubRepoId, privacy: .public)")
        logger.notice("useBackgroundSession=\(useBackgroundSession, privacy: .public)")
        logger.notice("loadingStrategy=\(loadingStrategy.debugDescription, privacy: .public)")

        // Store configuration for lazy loading
        self.modelConfig = ModelConfiguration(
            hubRepoId: hubRepoId,
            localURL: local,
            useBackgroundSession: useBackgroundSession
        )
        self.loadingStrategy = loadingStrategy
        self._model = nil
        self.modelCache = RagModelCache.shared

        let dbInitState: OSSignpostIntervalState = tracing.beginInterval("DatabaseInitialization")
        do {
            // Initialize DB (lightweight operation)
            self.database = try await RagDatabase(database: database)
            tracing.endInterval("DatabaseInitialization", dbInitState)
            logger.notice("Database initialized successfully")
        } catch {
            logger.error("Failed to initialize database: \(error, privacy: .public)")
            tracing.endInterval("DatabaseInitialization", dbInitState)
            throw error
        }

        // Handle different loading strategies
        switch loadingStrategy {
        case .eager:
            logger.info("Loading model eagerly as requested")
            _ = try await getModel()

        case .lazy:
            logger.notice("Rag actor initialized with deferred model loading")

        case .hybrid(let delay):
            logger.info("Scheduling model preload after \(delay)s")
            Task {
                do {
                    try await Task.sleep(for: .seconds(delay))
                    _ = try await getModel()
                } catch {
                    logger.error("Failed to preload model: \(error)")
                }
            }
        }
    }

    public init(
        from hubRepoId: String = "sentence-transformers/all-MiniLM-L6-v2",
        local: URL? = nil,
        useBackgroundSession: Bool = false,
        database: DatabaseLocation = .inMemory
    ) async throws {
        try await self.init(
            from: hubRepoId,
            local: local,
            useBackgroundSession: useBackgroundSession,
            database: database,
            loadingStrategy: .lazy
        )
    }

    // MARK: - Public Methods

    /// Processes the given file and returns a stream of progress updates.
    ///
    /// This method asynchronously processes the file at the specified URL, dividing it into chunks,
    /// storing each chunk in the database, and yielding progress updates as it proceeds. It uses
    /// internal tracing to mark the start and end of the overall file addition and the individual
    /// file processing intervals. In case of an unsupported file type or any processing error, the
    /// stream finishes with an error.
    ///
    /// - Parameters:
    ///   - fileURL: The URL of the file to process.
    ///   - id: A unique identifier for the processing object in the URL. Defaults to a new UUID.
    ///   - configuration: The processing configuration. Defaults to `.default`.
    ///
    /// - Returns: An asynchronous sequence (`AsyncThrowingStream<Progress, Error>`) that yields
    ///   progress updates during file processing.
    /// - Throws: `RagError.unsupportedFileType` if the file type is unsupported, or any other error
    ///   encountered during processing.
    ///
    /// # Example
    /// ```swift
    /// do {
    ///     for try await progress in await rag.add(fileURL: fileURL) {
    ///         print("Current progress: \(progress)")
    ///         // Perform additional actions based on progress updates.
    ///     }
    ///     print("File processing completed successfully.")
    /// } catch {
    ///     print("File processing failed with error: \(error)")
    /// }
    /// ```
    public func add(
        fileURL: URL,
        id: UUID = UUID(),
        configuration: Configuration = .default
    ) -> AsyncThrowingStream<Progress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await processFileInternal(
                        fileURL: fileURL,
                        id: id,
                        configuration: configuration,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Processes the given text and returns a stream of progress updates.
    ///
    /// This method asynchronously processes the provided text by dividing it into chunks,
    /// storing each chunk in the database, and yielding progress updates as it proceeds.
    /// It uses internal tracing to mark the start and end of the overall text addition and
    /// the individual text processing intervals. In case of any processing error, the
    /// stream finishes with an error.
    ///
    /// - Parameters:
    ///   - text: The text to process.
    ///   - id: A unique identifier for the processing object. Defaults to a new UUID.
    ///   - configuration: The processing configuration. Defaults to `.default`.
    ///
    /// - Returns: An asynchronous sequence (`AsyncThrowingStream<Progress, Error>`) that yields
    ///   progress updates during text processing.
    /// - Throws: Any error encountered during processing.
    public func add(
        text: String,
        id: UUID = UUID(),
        configuration: Configuration = .default
    ) -> AsyncThrowingStream<Progress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await processTextInternal(
                        text: text,
                        id: id,
                        configuration: configuration,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func semanticSearch(
        query: String,
        numResults: Int,
        threshold: Double, // 10.0 is my default
        table: String = Abstractions.Constants.defaultTable
    ) async throws -> [SearchResult] {
        let signpostID: OSSignpostID = tracing.makeSignpostID()
        let searchState: OSSignpostIntervalState = tracing.beginInterval("SemanticSearch", id: signpostID)

        logger.info("Performing semantic search with query length: \(query.count, privacy: .public)")
        logger.debug(
            """
            Search parameters: numResults=\(numResults, privacy: .public), \
            threshold=\(threshold, privacy: .public), table=\(table, privacy: .public)
            """
        )

        do {
            let encodingState: OSSignpostIntervalState = tracing.beginInterval("QueryEncoding", id: signpostID)
            let queryVector: [Float] = try await encodeQuery(query)
            tracing.endInterval("QueryEncoding", encodingState)
            logger.debug("Query encoded successfully")

            let vectorSearchState: OSSignpostIntervalState = tracing.beginInterval("VectorSearch", id: signpostID)
            let results: [SearchResult] = try await database.performVectorSearch(
                queryVector,
                limit: numResults,
                threshold: threshold,
                table: table
            )
            tracing.endInterval("VectorSearch", vectorSearchState)

            logger.notice("Search completed successfully with \(results.count, privacy: .public) results")
            tracing.endInterval("SemanticSearch", searchState)
            return results
        } catch {
            logger.error("Search failed: \(error, privacy: .public)")
            tracing.endInterval("SemanticSearch", searchState)
            throw error
        }
    }

    public func getChunk(
        index: Int,
        table: String = Abstractions.Constants.defaultTable
    ) async throws -> SearchResult {
        logger.debug("Retrieving chunk at index \(index, privacy: .public) from table \(table, privacy: .public)")

        do {
            let result: SearchResult = try await database.search(index: index, table: table)
            logger.debug("Successfully retrieved chunk")
            return result
        } catch {
            logger.error("Failed to retrieve chunk: \(error, privacy: .public)")
            throw error
        }
    }

    // MARK: - Private

    internal func getModel() async throws -> Bert.ModelBundle {
        // If model is already loaded, return it
        if let model = _model {
            return model
        }

        self.logger.info("Loading RAG model on first access")
        let signpostID: OSSignpostID = self.tracing.makeSignpostID()
        let modelLoadState: OSSignpostIntervalState = self.tracing.beginInterval("ModelLoading", id: signpostID)

        do {
            let model: Bert.ModelBundle = try await modelCache.model(for: modelConfig)
            self._model = model
            self.tracing.endInterval("ModelLoading", modelLoadState)
            self.logger.notice("RAG model loaded and cached successfully")
            return model
        } catch {
            self.logger.error("Failed to load RAG model: \(error, privacy: .public)")
            self.tracing.endInterval("ModelLoading", modelLoadState)
            throw error
        }
    }

    internal func encodeQuery(_ query: String) async throws -> [Float] {
        let signpostID: OSSignpostID = tracing.makeSignpostID()
        let encodingState: OSSignpostIntervalState = tracing.beginInterval("QueryEncoding", id: signpostID)
        defer {
            tracing.endInterval("QueryEncoding", encodingState)
        }

        do {
            let model: Bert.ModelBundle = try await getModel()
            let tensor: MLTensor = try model.encode(query)
            let vector: [Float] = try await tensor.convertTensorToVector()
            logger.debug("Query encoded successfully with vector size: \(vector.count, privacy: .public)")
            return vector
        } catch {
            logger.error("Query encoding failed: \(error, privacy: .public)")
            throw error
        }
    }
}
