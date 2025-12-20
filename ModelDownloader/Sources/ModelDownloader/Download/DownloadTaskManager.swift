import Foundation

/// Manages download tasks for models, providing centralized task lifecycle management
///
/// This actor ensures thread-safe management of download tasks, including:
/// - Storing and retrieving active tasks
/// - Cancelling individual or all tasks
/// - Preventing duplicate tasks for the same model
/// Uses HuggingFace repository IDs as identifiers.
public actor DownloadTaskManager {
    // MARK: - Properties

    /// Active download tasks indexed by repository ID
    private var activeTasks: [String: Task<Void, Never>] = [:]

    // MARK: - Initialization

    /// Creates a new download task manager
    public init() {}

    // MARK: - Task Management

    /// Stores a download task for a model
    /// - Parameters:
    ///   - task: The download task to store
    ///   - repositoryId: The repository ID of the model being downloaded
    /// - Note: If a task already exists for this repository ID, it will be cancelled and replaced
    public func store(task: Task<Void, Never>, for repositoryId: String) {
        // Cancel existing task if any
        if let existingTask = activeTasks[repositoryId] {
            existingTask.cancel()
        }

        // Store new task
        activeTasks[repositoryId] = task
    }

    /// Retrieves the download task for a model
    /// - Parameter repositoryId: The repository ID of the model
    /// - Returns: The active download task, or nil if none exists
    public func getTask(for repositoryId: String) -> Task<Void, Never>? {
        activeTasks[repositoryId]
    }

    /// Cancels and removes the download task for a model
    /// - Parameter repositoryId: The repository ID of the model
    /// - Returns: true if a task was cancelled, false if no task existed
    @discardableResult
    public func cancel(repositoryId: String) -> Bool {
        guard let task = activeTasks.removeValue(forKey: repositoryId) else {
            return false
        }

        task.cancel()
        return true
    }

    /// Cancels all active download tasks
    public func cancelAll() {
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
    }

    /// Removes a task from tracking
    /// - Parameter repositoryId: The repository ID of the model whose task to remove
    public func remove(repositoryId: String) {
        activeTasks.removeValue(forKey: repositoryId)
    }

    /// Gets all repository IDs with active download tasks
    /// - Returns: Array of repository IDs that have active downloads
    public func getActiveRepositoryIds() -> [String] {
        Array(activeTasks.keys)
    }

    // MARK: - Utility Methods

    /// Checks if a download is active for a model
    /// - Parameter repositoryId: The repository ID of the model
    /// - Returns: true if an active download exists
    public func isDownloading(repositoryId: String) -> Bool {
        activeTasks[repositoryId] != nil
    }

    /// Gets the count of active downloads
    /// - Returns: Number of active download tasks
    public func activeDownloadCount() -> Int {
        activeTasks.count
    }
}
