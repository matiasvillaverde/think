import Foundation

/// Protocol defining node mode controls.
public protocol NodeModeViewModeling: Actor {
    var isEnabled: Bool { get async }
    var isRunning: Bool { get async }
    var port: Int { get async }
    var authToken: String? { get async }

    func refresh() async
    func setEnabled(_ enabled: Bool) async
    func updatePort(_ port: Int) async
    func updateAuthToken(_ token: String?) async
}
