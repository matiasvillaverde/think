import Foundation

/// Generic view state enum for handling async operations
///
/// Provides type-safe state management for loading, success, and error states
/// across UI components. Follows SwiftLint compliance with explicit cases.
internal enum DiscoveryViewState<T, E: Error>: Sendable where T: Sendable, E: Sendable {
    /// Error state with failure information
    case error(E)

    /// Initial idle state before any operation
    case idle

    /// Success state with loaded data
    case loaded(T)

    /// Loading state during async operation
    case loading

    /// Whether the state is currently loading
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    /// Whether the state has loaded data
    var isLoaded: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }

    /// Whether the state has an error
    var hasError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    /// The loaded data if available
    var data: T? {
        if case let .loaded(data) = self {
            return data
        }
        return nil
    }

    /// The error if available
    var error: E? {
        if case let .error(error) = self {
            return error
        }
        return nil
    }
}

// MARK: - Image Loading States

/// Specific view state for image loading operations
internal typealias ImageViewState = DiscoveryViewState<Void, ImageLoadingError>

/// Errors that can occur during image loading
internal enum ImageLoadingError: Error, Sendable, LocalizedError {
    case cacheError
    case decodingError
    case invalidURL
    case networkError
    case unknown

    var errorDescription: String? {
        switch self {
        case .cacheError:
            String(localized: "Cache storage error", bundle: .module)

        case .decodingError:
            String(localized: "Image format not supported", bundle: .module)

        case .invalidURL:
            String(localized: "Invalid image URL", bundle: .module)

        case .networkError:
            String(localized: "Network connection error", bundle: .module)

        case .unknown:
            String(localized: "Unknown error occurred", bundle: .module)
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .cacheError:
            String(localized: "Clear app cache and try again", bundle: .module)

        case .decodingError:
            String(localized: "This image format is not supported", bundle: .module)

        case .invalidURL:
            String(localized: "The image link is not valid", bundle: .module)

        case .networkError:
            String(
                localized: "Check your internet connection and try again",
                bundle: .module
            )

        case .unknown:
            String(localized: "Please try again later", bundle: .module)
        }
    }
}

// MARK: - Metadata Loading States

/// Specific view state for metadata operations
internal typealias MetadataViewState<T> = DiscoveryViewState<T, MetadataError> where T: Sendable

/// Errors that can occur during metadata operations
internal enum MetadataError: Error, Sendable, LocalizedError {
    case missingData
    case parsingError
    case unknown

    var errorDescription: String? {
        switch self {
        case .missingData:
            String(localized: "Metadata not available", bundle: .module)

        case .parsingError:
            String(localized: "Unable to parse metadata", bundle: .module)

        case .unknown:
            String(localized: "Metadata error occurred", bundle: .module)
        }
    }
}
