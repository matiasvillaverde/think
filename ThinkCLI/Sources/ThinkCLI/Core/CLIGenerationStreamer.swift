import Abstractions
import Foundation

actor CLIStreamTracker {
    private var didStreamText: Bool = false

    func markText() {
        didStreamText = true
    }

    func snapshot() -> Bool {
        didStreamText
    }
}

enum CLIGenerationStreamer {
    static func stream(
        orchestrator: AgentOrchestrating,
        output: CLIOutput,
        tracker: CLIStreamTracker
    ) async {
        let eventStream = await orchestrator.eventStream
        var activeRunId: UUID?

        for await event in eventStream {
            if Task.isCancelled {
                return
            }

            switch event {
            case .generationStarted(let runId):
                activeRunId = runId

            case .textDelta(let text):
                output.stream(text)
                await tracker.markText()

            case .generationCompleted(let runId, _):
                if activeRunId == nil || activeRunId == runId {
                    return
                }

            case .generationFailed(let runId, _):
                if activeRunId == nil || activeRunId == runId {
                    return
                }

            default:
                continue
            }
        }
    }

    static func awaitCompletion(
        _ task: Task<Void, Never>,
        timeoutNanoseconds: UInt64
    ) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await task.value
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
            }
            _ = await group.next()
            group.cancelAll()
        }
        task.cancel()
    }
}
