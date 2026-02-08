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
        tracker: CLIStreamTracker,
        heartbeatSeconds: Double,
        verbose: Bool
    ) async {
        let eventStream = await orchestrator.eventStream
        var activeRunId: UUID?
        var heartbeatTask: Task<Void, Never>?

        for await event in eventStream {
            if Task.isCancelled {
                heartbeatTask?.cancel()
                return
            }

            switch event {
            case .generationStarted(let runId):
                activeRunId = runId
                heartbeatTask?.cancel()

                let interval = max(0, heartbeatSeconds)
                if interval > 0 {
                    heartbeatTask = Task {
                        while !Task.isCancelled {
                            let nanos = UInt64(interval * 1_000_000_000)
                            if nanos == 0 {
                                return
                            }
                            try? await Task.sleep(nanoseconds: nanos)
                            if Task.isCancelled {
                                return
                            }

                            // Heartbeats only emit in json-lines to keep stdout machine-readable.
                            output.heartbeat()

                            if verbose {
                                let data = Data("[heartbeat] still thinking...\n".utf8)
                                FileHandle.standardError.write(data)
                            }
                        }
                    }
                }

            case .textDelta(let text):
                output.stream(text)
                await tracker.markText()

            case .generationCompleted(let runId, _):
                if activeRunId == nil || activeRunId == runId {
                    heartbeatTask?.cancel()
                    return
                }

            case .generationFailed(let runId, _):
                if activeRunId == nil || activeRunId == runId {
                    heartbeatTask?.cancel()
                    return
                }

            default:
                continue
            }
        }

        heartbeatTask?.cancel()
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
