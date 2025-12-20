import Foundation

/// Protocol for view models that control input and UI interactions
public protocol ViewModelInputControlling: MainActor {
    /// Removes focus from the input field
    func removeFocus()
    /// Sets focus to the input field
    func focus()
    /// Scrolls the view to the bottom
    func scrollToBottom()
    /// Adds a callback for when focus is removed
    /// - Parameter onRemoveFocus: Closure to execute when focus is removed
    func add(onRemoveFocus: @escaping () -> Void)
    /// Adds a callback for when focus is set
    /// - Parameter onFocus: Closure to execute when focus is set
    func add(onFocus: @escaping () -> Void)
    /// Adds a callback for scrolling to bottom
    /// - Parameter onScrollToBottom: Closure to execute when scrolling to bottom
    func add(onScrollToBottom: @escaping () -> Void)
}
