import Testing

// MARK: - Test Configurations

/// Extension providing standard test tags for categorizing tests
public extension Tag {
    /// Tag for performance-related tests
    @Tag static var performance: Self
    /// Tag for state management tests
    @Tag static var state: Self
    /// Tag for acceptance tests
    @Tag static var acceptance: Self
    /// Tag for edge case tests
    @Tag static var edge: Self
    /// Tag for core functionality tests
    @Tag static var core: Self
    /// Tag for integration tests
    @Tag static var integration: Self
    /// Tag for concurrency tests
    @Tag static var concurrency: Self
    /// Tag for regression tests
    @Tag static var regression: Self
    /// Tag for error handling tests
    @Tag static var error: Self
    /// Tag for download-related tests
    @Tag static var download: Self
    /// Tag for generation-related tests
    @Tag static var generation: Self
    /// Tag for loading-related tests
    @Tag static var loading: Self
}
