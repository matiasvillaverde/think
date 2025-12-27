import Foundation

public protocol AudioViewModeling: Actor {
    func say(_ text: String)
    func listen(generator: ViewModelGenerating) async
    func stopListening()

    var talkModeState: TalkModeState { get async }
    var wakePhrase: String { get async }
    var isWakeWordEnabled: Bool { get async }
    var isTalkModeEnabled: Bool { get async }

    func startTalkMode(generator: ViewModelGenerating) async
    func stopTalkMode() async
    func updateWakePhrase(_ phrase: String) async
    func setWakeWordEnabled(_ enabled: Bool) async
}
