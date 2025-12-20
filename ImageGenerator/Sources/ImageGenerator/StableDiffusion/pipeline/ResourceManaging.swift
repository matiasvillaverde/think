/// Protocol for managing internal resources
public protocol ResourceManaging {
    /// Request resources to be loaded and ready if possible
    func loadResources() throws

    /// Request resources are unloaded / remove from memory if possible
    func unloadResources()
}

extension ResourceManaging {
    /// Request resources are pre-warmed by loading and unloading
    func prewarmResources() throws {
        try loadResources()
        unloadResources()
    }
}
