import Foundation
import MLX

// swiftlint:disable force_unwrapping unused_optional_binding

internal class BenchmarkTimer: @unchecked Sendable {
    private class Timing {
        let id: String

        private var start: DispatchTime
        private var finish: DispatchTime?
        private var childTasks: [Timing] = []
        let parent: Timing?
        private var delta: UInt64 = 0

        init(id: String, parent: Timing?) {
            start = DispatchTime.now()
            self.id = id
            self.parent = parent
            if let parent { parent.childTasks.append(self) }
        }

        func startTimer() {
            start = DispatchTime.now()
        }

        func stop() {
            finish = DispatchTime.now()
            delta += finish!.uptimeNanoseconds - start.uptimeNanoseconds
        }

        func log(spaces: Int = 0) {
            guard let _ = finish else { return }

            let spaceString: String = String(repeating: " ", count: spaces)
            logPrint(spaceString + id + ": " + deltaInSec + " sec")
            for childTask in childTasks {
                childTask.log(spaces: spaces + 2)
            }
        }

        var deltaTime: Double { Double(delta) / 1_000_000_000 }
        var deltaInSec: String { String(format: "%.4f", Double(delta) / 1_000_000_000) }

        deinit {
            // No cleanup needed
        }
    }

    static let shared: BenchmarkTimer = BenchmarkTimer()

    private init() {}

    private var timers: [String: Timing] = [:]

    @discardableResult
    private func create(id: String, parent parentId: String? = nil) -> Timing? {
        guard timers[id] == nil else { return timers[id] }

        var parentTiming: Timing?
        if let parentId {
            parentTiming = timers[parentId]
            guard parentTiming != nil else { return nil }
        }

        timers[id] = Timing(id: id, parent: parentTiming)
        return timers[id]
    }

    private func stop(id: String) {
        guard let timing = timers[id] else { return }
        timing.stop()
    }

    private func printLogs(id: String) {
        guard let timing = timers[id] else { return }
        timing.log()
    }

    private func reset() {
        timers = [:]
    }

    private func exists(id: String) -> Timing? {
        timers[id]
    }

#if DEBUG

    @inline(__always) static func startTimer(_ id: String, _ parent: String? = nil) {
        if let timer = Self.shared.create(id: id, parent: parent) {
            timer.startTimer()
        }
    }

    @inline(__always) static func stopTimer(_ id: String, _ arrays: [MLXArray] = []) {
        arrays.forEach { $0.eval() }

        if let timer = Self.shared.exists(id: id) {
            timer.stop()
        }
    }

    static func print() {
        for (key, timing) in Self.shared.timers where timing.parent == nil {
            Self.shared.printLogs(id: key)
        }
    }

    static func reset() {
        Self.shared.reset()
    }

    @inline(__always) static func getTimeInSec(_ id: String) -> Double? {
        Self.shared.timers[id]?.deltaTime
    }

#else

    @inline(__always) static func startTimer(_: String, _: String? = nil) {}
    @inline(__always) static func stopTimer(_: String, _: [MLXArray] = []) {}
    @inline(__always) static func print() {}
    @inline(__always) static func reset() {}
    @inline(__always) static func getTimeInSec(_: String) -> Double? { 0.0 }

#endif

    deinit {
        // No cleanup needed
    }
}
// swiftlint:enable force_unwrapping unused_optional_binding
