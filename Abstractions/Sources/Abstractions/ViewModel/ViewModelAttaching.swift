import Foundation

/// Protocol for view models that handle file attachments
public protocol ViewModelAttaching: Actor {
    /// Processes an attached file
    /// - Parameters:
    ///   - file: The URL of the file to process
    ///   - chatId: The chat session identifier
    func process(file: URL, chatId: UUID) async
    /// Shows an error related to file attachment
    /// - Parameter error: The error to display
    func show(error: Error) async
    /// Deletes an attached file
    /// - Parameter file: The UUID of the file to delete
    func delete(file: UUID) async
}
