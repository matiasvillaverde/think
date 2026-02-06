import SwiftData
import Foundation
import Abstractions
import OSLog

/// NewDatabase provides a singleton database instance that can be configured through SwiftUI's environment.
///
/// # Usage
/// To use NewDatabase in your SwiftUI app, configure it in your App's scene:
/// ```swift
/// @main
/// struct MyApp: App {
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///                 .environment(\.databaseConfiguration, DatabaseConfiguration(
///                     isStoredInMemoryOnly: false,
///                     allowsSave: true
///                 ))
///                 .withDatabase()
///         }
///     }
/// }
/// ```
///
/// The database can then be accessed in any view using the environment:
/// ```swift
/// struct ContentView: View {
///     @Environment(\.database) private var database
///
///     var body: some View {
///         // Use database here
///     }
/// }
/// ```
///
/// # Thread Safety
/// The database uses actor isolation for thread-safe initialization and state management.
/// All database operations are performed through async methods to ensure thread safety.
@ModelActor
public actor Database: DatabaseProtocol {
    // Singleton instance - using nonisolated(unsafe) for static storage
    // Access is controlled through the actor-isolated instance method
    nonisolated(unsafe) private static var shared: Database?

    private let state: DatabaseState = DatabaseState()

    @MainActor
    @Published
    public private(set) var status: DatabaseStatus = .new

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.example.app",
        category: "Database"
    )

    private init(configuration: DatabaseConfiguration) throws {
        Self.logger.info("Database initialization started")
        Self.logger.info("Configuration: memory-only=\(configuration.isStoredInMemoryOnly), allowsSave=\(configuration.allowsSave)")
        
        let resolvedStoreName: String
        let resolvedStoreURL: URL?
        if let storeURL = configuration.storeURL {
            resolvedStoreName = storeURL.lastPathComponent
            resolvedStoreURL = storeURL
        } else {
            resolvedStoreName = DatabaseStoreLocator.defaultStoreName
            resolvedStoreURL = DatabaseStoreLocator.defaultStoreURL(storeName: resolvedStoreName)
        }

        if !configuration.isStoredInMemoryOnly, let storeURL = resolvedStoreURL {
            DatabaseStoreResetPolicy.prepareStoreIfNeeded(storeURL: storeURL, logger: Self.logger)
        }

        let config = ModelConfiguration(
            resolvedStoreName,
            isStoredInMemoryOnly: configuration.isStoredInMemoryOnly,
            allowsSave: configuration.allowsSave
        )

        do {
            Self.logger.info("Creating ModelContainer with SwiftData models...")
            Self.logger.info("""
                Models to register: LLMConfiguration, DiffusorConfiguration, User, AppSettings, Prompt, \
                ImageAttachment, FileAttachment, Metrics, Chat, CanvasDocument, AutomationSchedule, Message, Memory, Skill, \
                ToolPolicy, SubAgentRun, Tool, Source, Model, Tag, NotificationAlert, Personality, ModelDetails, ToolExecution
                """)
            
            modelContainer = try ModelContainer(
                for:
                LLMConfiguration.self,
                DiffusorConfiguration.self,
                User.self,
                AppSettings.self,
                Prompt.self,
                ImageAttachment.self,
                FileAttachment.self,
                Metrics.self,
                Chat.self,
                CanvasDocument.self,
                AutomationSchedule.self,
                Message.self,
                Memory.self,
                Skill.self,
                ToolPolicy.self,
                SubAgentRun.self,
                Source.self,
                Model.self,
                Tag.self,
                NotificationAlert.self,
                Personality.self,
                ModelDetails.self,
                ToolExecution.self,
                configurations: config
            )
            
            Self.logger.info("ModelContainer created successfully")

            modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
            Self.logger.info("ModelExecutor created successfully")

            // Move heavy work to the background
            Task.detached(priority: .high) { [weak self] in
                let callback: @MainActor @Sendable (DatabaseStatus) -> Void = { [weak self] newStatus in
                    guard let self else { return }
                    self.status = newStatus
                }

                await MainActor.run { [weak self] in
                    self?.state.onStatusChange = callback
                }

                guard let self else { return }
                await DatabaseInitializationGate.shared.run {
                    await self.initialize(configuration: configuration)
                }
            }
        } catch {
            Self.logger.error("Failed to create ModelContainer")
            Self.logger.error("Error type: \(type(of: error))")
            Self.logger.error("Error description: \(error)")
            
            // Check if it's a Core Data error
            let nsError = error as NSError
            Self.logger.error("NSError domain: \(nsError.domain)")
            Self.logger.error("NSError code: \(nsError.code)")
            Self.logger.error("NSError userInfo: \(nsError.userInfo)")
            
            // Check for specific migration errors
            if nsError.domain == "NSCocoaErrorDomain", nsError.code == 134110 {
                Self.logger.error("This appears to be a migration error")
                if let reason = nsError.userInfo["reason"] as? String {
                    Self.logger.error("Migration failure reason: \(reason)")
                }
                if let sourceURL = nsError.userInfo["sourceURL"] as? URL {
                    Self.logger.error("Source store URL: \(sourceURL)")
                }
                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    Self.logger.error("Underlying error: \(underlyingError)")
                    Self.logger.error("Underlying error userInfo: \(underlyingError.userInfo)")
                }
            }
            
            throw error
        }
    }

    // MARK: - Public Access Methods

    /// Provides non-failing access to the singleton database instance
    /// - Returns: A shared database instance with default configuration
    public static func instance(configuration: DatabaseConfiguration) -> Database {
        if let existing = shared {
            return existing
        }

        do {
            // Try to create with default configuration
            let instance = try Database(configuration: configuration)
            shared = instance
            return instance
        } catch {
            // Get detailed error information
            let nsError = error as NSError
            let errorDetails = """
                    Database initialization failed:
                    - Error: \(error.localizedDescription)
                    - Domain: \(nsError.domain)
                    - Code: \(nsError.code)
                    - Description: \(nsError)
                    - User Info: \(nsError.userInfo)
                    - Configuration: memory-only=\(configuration.isStoredInMemoryOnly), \
                    allowsSave=\(configuration.allowsSave)
                    """

            // Log to system log (viewable in Console.app)
            self.logger.error("\(errorDetails, privacy: .public)")

            // Print to console for immediate debugging
            print(errorDetails)

            // Log stack trace if available
            logger.error("Stack trace:\n\(Thread.callStackSymbols.joined(separator: "\n"), privacy: .public)")

            // Try creating an in-memory database as fallback
            do {
                logger.notice("Attempting to create fallback in-memory database")
                let fallbackConfig = DatabaseConfiguration(
                    isStoredInMemoryOnly: true,
                    allowsSave: true,
                    ragFactory: configuration.ragFactory
                )
                let fallbackInstance = try Database(configuration: fallbackConfig)
                shared = fallbackInstance

                // Log success of fallback
                logger.notice("Successfully created fallback in-memory database")

                return fallbackInstance
            } catch let fallbackError {
                // If fallback fails too, log both errors
                let fallbackErrorDetails = """
                        Fallback database initialization also failed:
                        - Original error: \(error)
                        - Fallback error: \(fallbackError)
                        """

                logger.fault("\(fallbackErrorDetails, privacy: .public)")
                print(fallbackErrorDetails)

                // You could also save these errors to a file before crashing
                // This approach gives you time to log before the crash
                let errorLog = "Fatal database error: \(errorDetails)\n\(fallbackErrorDetails)"
                try? errorLog.write(
                    toFile: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("db_fatal_error.log").path,
                    atomically: true,
                    encoding: .utf8
                )

                // Only now do we trigger the fatal error
                fatalError(fallbackErrorDetails)
            }
        }
    }

    /// Internal API for creating database with custom configuration
    /// - Parameter configuration: The database configuration
    /// - Returns: A configured database instance
    /// - Throws: Errors from database initialization
    public static func new(configuration: DatabaseConfiguration) throws -> Database {
        try Database(configuration: configuration)
    }

    private func initialize(
        configuration: DatabaseConfiguration
    ) async {
        precondition(Thread.isMainThread == false)
        
        Self.logger.info("Beginning database initialization")

        do {
            // Load or create the user object
            Self.logger.info("Loading or creating user...")
            let user = try loadUser()
            Self.logger.info("User loaded successfully: \(user.id)")

            // RAG initialization interval
            Self.logger.info("Initializing RAG system...")
            let rag = try await configuration.ragFactory.createRag(
                isStoredInMemoryOnly: configuration.isStoredInMemoryOnly
            )
            Self.logger.info("RAG system initialized")

            // Final state update
            Self.logger.info("Setting database state to ready...")
            try await state.setReady(rag: rag, userId: user.persistentModelID)
            Self.logger.info("Database ready with user ID: \(user.id)")
        } catch {
            Self.logger.error("Database initialization failed: \(error)")
            await state.setError(error)
        }
    }

    private func loadUser() throws -> User {
        precondition(Thread.isMainThread == false)

        let descriptor = FetchDescriptor<User>()

        if let existingUser = try modelExecutor.modelContext.performFetch(descriptor).first {
            return existingUser
        }

        // Create the Logged in User
        let newUser = User()
        modelExecutor.modelContext.insert(newUser)
        try modelExecutor.modelContext.save()

        return newUser
    }
}

// MARK: - Initialization Gate

/// Serializes database initialization work to avoid SwiftData concurrency crashes
/// when many in-memory databases are created in parallel during tests.
private actor DatabaseInitializationGate {
    static let shared = DatabaseInitializationGate()

    private var isRunning: Bool = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func run(_ operation: @Sendable () async -> Void) async {
        await acquire()
        defer { release() }
        await operation()
    }

    private func acquire() async {
        if !isRunning {
            isRunning = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        if waiters.isEmpty {
            isRunning = false
            return
        }

        let continuation = waiters.removeFirst()
        continuation.resume()
    }
}

// MARK: - UI

extension Database {
    @preconcurrency
    @MainActor
    @discardableResult
    public func write<T: WriteCommand>(_ command: T) async throws -> T.Result {
        let (rag, userId) = try await state.waitUntilReady()

        return try command.execute(
            in: modelContainer.mainContext,
            userId: command.requiresUser ? userId : nil,
            rag: command.requiresRag ? rag : nil
        )
    }

    @preconcurrency
    @MainActor
    public func read<T: ReadCommand>(_ command: T) async throws -> T.Result {
        let (rag, userId) = try await state.waitUntilReady()

        return try command.execute(
            in: modelContainer.mainContext,
            userId: command.requiresUser ? userId : nil,
            rag: command.requiresRag ? rag : nil
        )
    }

    @preconcurrency
    @MainActor
    @discardableResult
    public func execute<T: AnonymousCommand>(_ command: T) async throws -> T.Result {
        let (rag, userId) = try await state.waitUntilReady()

        let result = try command.execute(
            in: modelContainer.mainContext,
            userId: command.requiresUser ? userId : nil,
            rag: command.requiresRag ? rag : nil
        )

        // Save changes for anonymous commands
        try modelContainer.mainContext.save()

        return result
    }

    @preconcurrency
    @MainActor
    public func save() throws {
        try modelExecutor.modelContext.save()
        try modelContainer.mainContext.save()
    }
}

// MARK: - Background work

extension Database {
    public func writeInBackground<T: WriteCommand>(_ command: T) async throws {
        // Get everything we need before the transaction
        let (rag, userId) = try await self.state.waitUntilReady()
        let commandUserId = command.requiresUser ? userId : nil
        let commandRag = command.requiresRag ? rag : nil

        // Then wrap the save in a transaction
        try self.modelExecutor.modelContext.transaction {
            precondition(Thread.isMainThread == false)
            _ = try command.execute(
                in: self.modelExecutor.modelContext,
                userId: commandUserId,
                rag: commandRag
            )
        }

        await MainActor.run { [modelContainer] in
            modelContainer.mainContext.processPendingChanges()
        }
    }

    public func readInBackground<T: ReadCommand>(_ command: T) async throws -> T.Result {
        precondition(Thread.isMainThread == false)
        let (rag, userId) = try await self.state.waitUntilReady()
        return try command.execute(
            in: self.modelExecutor.modelContext,
            userId: command.requiresUser ? userId : nil,
            rag: command.requiresRag ? rag : nil
        )
    }

    public func semanticSearch(
        query: String,
        table: String,
        numResults: Int,
        threshold: Double
    ) async throws -> [SearchResult] {
        precondition(Thread.isMainThread == false)

        let (rag, _) = try await self.state.waitUntilReady()

        let results = try await rag.semanticSearch(
            query: query,
            numResults: numResults,
            threshold: threshold,
            table: table
        )

        return results
    }

    public func indexText(
        _ text: String,
        id: UUID,
        table: String
    ) async throws {
        precondition(Thread.isMainThread == false)

        let (rag, _) = try await self.state.waitUntilReady()

        let configuration = Configuration(
            tokenUnit: .sentence,
            strategy: .extractKeywords,
            table: table
        )

        for try await _ in await rag.add(text: text, id: id, configuration: configuration) {
            // Progress updates - we just wait for completion
        }

        Self.logger.info("Indexed text with id \(id) in table \(table)")
    }

    public func deleteFromIndex(
        id: UUID,
        table: String
    ) async throws {
        precondition(Thread.isMainThread == false)

        let (rag, _) = try await self.state.waitUntilReady()

        try await rag.delete(id: id, table: table)

        Self.logger.info("Deleted indexed content with id \(id) from table \(table)")
    }

    public func searchMemories(
        query: String,
        userId: UUID,
        limit: Int,
        threshold: Double
    ) async throws -> [UUID] {
        precondition(Thread.isMainThread == false)

        let table = RagTableName.memoryTableName(userId: userId)

        let results = try await semanticSearch(
            query: query,
            table: table,
            numResults: limit,
            threshold: threshold
        )

        // Extract memory IDs from search results
        let memoryIds = results.compactMap { $0.id }

        Self.logger.info("Found \(memoryIds.count) memories for query in table \(table)")
        return memoryIds
    }
}
