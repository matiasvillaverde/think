import Foundation

public protocol AudioViewModeling: Actor {
    func say(_ text: String)
    func listen(generator: ViewModelGenerating) async
    func stopListening()
}
