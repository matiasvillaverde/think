import Foundation

/// Protocol defining the public interface for audio generation capabilities
public protocol AudioGenerating: Actor {
    func say(_ text: String) async
    func hear() -> String?
}
