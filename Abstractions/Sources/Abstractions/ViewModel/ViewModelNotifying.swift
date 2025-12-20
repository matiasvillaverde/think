import Foundation

public protocol ViewModelNotifying: Actor {
    func markNotificationAsRead(_ notification: UUID) async
    func showMessage(_ message: String) async
}
