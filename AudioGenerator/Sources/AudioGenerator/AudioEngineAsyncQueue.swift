import Foundation

internal actor AudioEngineAsyncQueue {
    private var items: [[Float]] = []
    private var dequeueTasks: [CheckedContinuation<[Float]?, Never>] = []
    private var isComplete: Bool = false
    private var processedItems: Int = 0
    private var totalItems: Int = 0

    func setTotalItems(_ count: Int) {
        totalItems = count
    }

    func markAsComplete() {
        isComplete = true
        if items.isEmpty {
            for continuation in dequeueTasks {
                continuation.resume(returning: nil)
            }
            dequeueTasks.removeAll()
        }
    }

    func enqueue(_ item: [Float]) {
        if let continuation: CheckedContinuation<[Float]?, Never> = dequeueTasks.first {
            dequeueTasks.removeFirst()
            continuation.resume(returning: item)
        } else {
            items.append(item)
        }
    }

    func dequeueUntilComplete() async -> [Float]? {
        if let item: [Float] = items.first {
            items.removeFirst()
            processedItems += 1
            return item
        }
        if isComplete,
           processedItems >= totalItems {
            return nil
        }
        return await withCheckedContinuation { continuation in
            dequeueTasks.append(continuation)
        }
    }
}
