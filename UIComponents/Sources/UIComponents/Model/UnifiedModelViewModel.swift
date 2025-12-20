import Abstractions
import Database
import Foundation
import SwiftUI

/// ViewModel for UnifiedModelView following MVVM architecture
@preconcurrency
@MainActor
public class UnifiedModelViewModel: ObservableObject {
    // MARK: - Types

    /// Either a local Model or a DiscoveredModel
    public enum ModelInput {
        case model(Model)
        case discovered(DiscoveredModel)
    }

    /// Display mode for the unified model view
    public enum DisplayMode {
        case small // Square, no download button
        case large // Card with download button
    }

    // MARK: - Published Properties

    @Published public private(set) var modelInput: ModelInput
    @Published public private(set) var displayMode: DisplayMode
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?

    // MARK: - Cached Properties

    private var _cachedFormattedSize: String?

    // MARK: - Initialization

    /// Initialize with a Model entity
    /// - Parameters:
    ///   - model: The Model entity
    ///   - displayMode: The display mode (default: .large)
    public init(model: Model, displayMode: DisplayMode = .large) {
        modelInput = .model(model)
        self.displayMode = displayMode
    }

    /// Initialize with a DiscoveredModel entity
    /// - Parameters:
    ///   - discoveredModel: The DiscoveredModel entity
    ///   - displayMode: The display mode (default: .large)
    public init(discoveredModel: DiscoveredModel, displayMode: DisplayMode = .large) {
        modelInput = .discovered(discoveredModel)
        self.displayMode = displayMode
    }

    // MARK: - Computed Properties

    /// The model's display title
    public var title: String {
        switch modelInput {
        case let .model(model):
            model.displayName

        case let .discovered(discovered):
            discovered.name
        }
    }

    /// The model's author
    public var author: String {
        switch modelInput {
        case let .model(model):
            model.author ?? "Unknown"

        case let .discovered(discovered):
            discovered.author
        }
    }

    /// The model's image URL (if available)
    public var imageURL: URL? {
        switch modelInput {
        case .model:
            // Models may have cached image data but no URL
            nil

        case let .discovered(discovered):
            discovered.imageUrls.first.flatMap(URL.init)
                ?? discovered.cardData?.thumbnail.flatMap(URL.init)
        }
    }

    /// The model's backend type as a string
    public var backendType: String {
        switch modelInput {
        case let .model(model):
            model.backend.rawValue

        case let .discovered(discovered):
            discovered.detectedBackends.first?.rawValue ?? "Unknown"
        }
    }

    /// The model's tags
    public var tags: [String] {
        switch modelInput {
        case let .model(model):
            model.tags.compactMap(\.name)

        case let .discovered(discovered):
            discovered.tags
        }
    }

    /// The model's formatted size
    public var formattedSize: String {
        if let cached = _cachedFormattedSize {
            return cached
        }

        let size: UInt64 = switch modelInput {
        case let .model(model):
            model.size

        case let .discovered(discovered):
            UInt64(discovered.totalSize)
        }

        let formatted: String = ByteCountFormatter.string(
            fromByteCount: Int64(size),
            countStyle: .file
        )

        _cachedFormattedSize = formatted
        return formatted
    }

    /// Whether the view is in small mode
    public var isSmallMode: Bool {
        displayMode == .small
    }

    /// Whether the download button should be shown
    public var shouldShowDownloadButton: Bool {
        displayMode == .large
    }

    // MARK: - Public Methods

    /// Set loading state
    /// - Parameter loading: Whether the view is loading
    public func setLoading(_ loading: Bool) {
        isLoading = loading
        // Clear error when starting loading
        if loading {
            errorMessage = nil
        }
    }

    /// Set error message
    /// - Parameter message: The error message to display
    public func setError(_ message: String) {
        guard !message.isEmpty else {
            return
        }
        errorMessage = message
        // Clear loading when error occurs
        isLoading = false
    }

    /// Clear error message
    public func clearError() {
        errorMessage = nil
    }

    // MARK: - Deinit

    deinit {
        // Clean up any resources if needed
    }
}
