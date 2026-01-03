import Abstractions
import Database
import Foundation

internal actor CanvasUpdateScheduler {
    private let debounceNanoseconds: UInt64
    private var pendingUpdate: Task<Void, Never>?

    init(debounceNanoseconds: UInt64) {
        self.debounceNanoseconds = debounceNanoseconds
    }

    func scheduleUpdate(
        database: DatabaseProtocol,
        canvasId: UUID,
        title: String,
        content: String
    ) {
        pendingUpdate?.cancel()
        pendingUpdate = Task { [debounceNanoseconds] in
            do {
                try await Task.sleep(nanoseconds: debounceNanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            _ = try? await database.write(
                CanvasCommands.Update(
                    id: canvasId,
                    title: title,
                    content: content
                )
            )
        }
    }

    func flush(
        database: DatabaseProtocol,
        canvasId: UUID,
        title: String,
        content: String
    ) async {
        pendingUpdate?.cancel()
        pendingUpdate = nil

        _ = try? await database.write(
            CanvasCommands.Update(
                id: canvasId,
                title: title,
                content: content
            )
        )
    }
}
