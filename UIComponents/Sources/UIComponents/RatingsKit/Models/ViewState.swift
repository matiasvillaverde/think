/// A generic enum representing the different states of a view that loads data asynchronously.
///
/// This enum is used to handle the three common states of data-driven views:
/// - Loading: Data is being fetched or processed
/// - Loaded: Data has been successfully retrieved
/// - Error: An error occurred during data fetching or processing
public enum ViewState<T> {
    /// Indicates that an error occurred during loading.
    /// - Parameter String: A description of the error.
    case error(String)

    /// Indicates that data has been successfully loaded.
    /// - Parameter T: The loaded data.
    case loaded(T)

    /// Indicates that data is currently being loaded.
    case loading

    /// The successfully loaded value, if available.
    ///
    /// Returns `nil` if the state is not `.loaded`.
    var value: T? {
        if case let .loaded(value) = self {
            return value
        }
        return nil
    }

    /// A Boolean value indicating whether the state is `.loading`.
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    /// The error message if the state is `.error`, otherwise `nil`.
    var errorMessage: String? {
        if case let .error(message) = self {
            return message
        }
        return nil
    }
}
