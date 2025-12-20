import Foundation
import Abstractions
import SwiftData
import OSLog

// MARK: - Database State
actor DatabaseState {
    enum Status {
        case partiallyReady
        case ready(rag: Ragging, userId: PersistentIdentifier)
        case failed(Error)
    }

    private var status: Status = .partiallyReady
    private var continuations: [CheckedContinuation<Void, Error>] = []
    private let logger = Logger.database
    @MainActor
    var onStatusChange: (@MainActor (DatabaseStatus) -> Void)?

    init() { }

    func setReady(rag: Ragging, userId: PersistentIdentifier) async throws {
        guard case .partiallyReady = status else {
            throw DatabaseError.invalidStateTransition
        }
        status = .ready(rag: rag, userId: userId)
        logger.info("Database ready with user ID: \(userId.storeIdentifier ?? "unknown")")
        await MainActor.run {
            onStatusChange?(.ready)
        }
        resumeContinuations()
    }

    func setError(_ error: Error) async {
        status = .failed(error)
        logger.error("Database failed: \(error.localizedDescription)")
        await MainActor.run {
            onStatusChange?(.failed(error as NSError))
        }
        resumeContinuations(with: error)
    }

    func waitUntilReady() async throws -> (rag: Ragging, userId: PersistentIdentifier) {
        switch status {
        case .partiallyReady:
            try await withCheckedThrowingContinuation { continuation in
                continuations.append(continuation)
            }
            return try await waitUntilReady()

        case .ready(let rag, let userId):
            return (rag: rag, userId: userId)

        case .failed(let error):
            throw error
        }
    }

    private func resumeContinuations(with error: Error? = nil) {
        continuations.forEach { continuation in
            if let error { continuation.resume(throwing: error) } else { continuation.resume() }
        }
        continuations.removeAll()
    }
}
