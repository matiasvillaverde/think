import Abstractions
import Foundation
import NaturalLanguage
import OSLog
import PDFKit

private let kLogger: Logger = Logger(subsystem: "RAG", category: "PDFProcessor")

private actor PDFStreamYielder {
    private var processedPages: Int = 0

    func yield(
        _ chunks: [ChunkData],
        progress: Progress,
        to continuation: AsyncThrowingStream<([ChunkData], Progress), Error>.Continuation
    ) {
        processedPages += 1
        progress.completedUnitCount = Int64(processedPages)
        guard !chunks.isEmpty else {
            return
        }

        let snapshot: Progress = Progress(totalUnitCount: progress.totalUnitCount)
        snapshot.completedUnitCount = progress.completedUnitCount
        snapshot.kind = progress.kind
        snapshot.fileOperationKind = progress.fileOperationKind

        continuation.yield((chunks, snapshot))
    }
}

private struct PDFPageProcessingContext {
    let document: PDFDocument
    let tokenUnit: NLTokenUnit
    let chunking: ChunkingConfiguration
    let strategy: FileProcessingStrategy
    let progress: Progress
    let yielder: PDFStreamYielder
    let continuation: AsyncThrowingStream<([ChunkData], Progress), Error>.Continuation
}

extension FileProcessor {
    internal func processPDFFileAsync(
        _ url: URL,
        tokenUnit: NLTokenUnit,
        chunking: ChunkingConfiguration,
        strategy: FileProcessingStrategy
    ) -> AsyncThrowingStream<([ChunkData], Progress), Error> {
        AsyncThrowingStream { @Sendable continuation in
            let task: Task<Void, Never> = Task {
                do {
                    try await processPDFDocument(
                        url: url,
                        tokenUnit: tokenUnit,
                        chunking: chunking,
                        strategy: strategy,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func processPDFDocument(
        url: URL,
        tokenUnit: NLTokenUnit,
        chunking: ChunkingConfiguration,
        strategy: FileProcessingStrategy,
        continuation: AsyncThrowingStream<([ChunkData], Progress), Error>.Continuation
    ) async throws {
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            throw FileProcessorError.couldNotReadFile("We don't have access \(url.absoluteString)")
        }

        defer {
            // Make sure we release the security-scoped resource when done
            url.stopAccessingSecurityScopedResource()
        }

        guard let pdfDocument = PDFDocument(url: url) else {
            throw FileProcessorError.pdfTextExtractionFailed
        }

        try await processPDFPages(
            document: pdfDocument,
            tokenUnit: tokenUnit,
            chunking: chunking,
            strategy: strategy,
            continuation: continuation
        )
    }

    private func processPDFPages(
        document: PDFDocument,
        tokenUnit: NLTokenUnit,
        chunking: ChunkingConfiguration,
        strategy: FileProcessingStrategy,
        continuation: AsyncThrowingStream<([ChunkData], Progress), Error>.Continuation
    ) async throws {
        let pageCount: Int = document.pageCount
        let progress: Progress = makeProgress(pageCount: pageCount)
        let yielder: PDFStreamYielder = PDFStreamYielder()
        let pagesPerBatch: Int = pagesPerBatch(pageCount: pageCount)
        let context: PDFPageProcessingContext = PDFPageProcessingContext(
            document: document,
            tokenUnit: tokenUnit,
            chunking: chunking,
            strategy: strategy,
            progress: progress,
            yielder: yielder,
            continuation: continuation
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for batchStart in stride(from: 0, to: pageCount, by: pagesPerBatch) {
                let batchEnd: Int = min(batchStart + pagesPerBatch, pageCount)
                addPageTasks(
                    for: batchStart..<batchEnd,
                    context: context,
                    group: &group
                )
            }

            try await group.waitForAll()
        }
    }

    private func pagesPerBatch(pageCount: Int) -> Int {
        let processorCount: Int = max(1, ProcessInfo.processInfo.activeProcessorCount)
        return max(1, pageCount / processorCount)
    }

    private func makeProgress(pageCount: Int) -> Progress {
        let progress: Progress = Progress(totalUnitCount: Int64(pageCount))
        progress.kind = .file
        progress.fileOperationKind = .duplicating
        return progress
    }

    private func addPageTasks(
        for pageRange: Range<Int>,
        context: PDFPageProcessingContext,
        group: inout ThrowingTaskGroup<Void, Error>
    ) {
        let tokenUnit: NLTokenUnit = context.tokenUnit
        let chunking: ChunkingConfiguration = context.chunking
        let strategy: FileProcessingStrategy = context.strategy
        let progress: Progress = context.progress
        let yielder: PDFStreamYielder = context.yielder
        let continuation: AsyncThrowingStream<([ChunkData], Progress), Error>.Continuation = context.continuation

        for pageIndex in pageRange {
            guard let text = pageText(document: context.document, pageIndex: pageIndex) else {
                continue
            }

            group.addTask { @Sendable in
                let processedChunks: [ChunkData] = try await processPDFPage(
                    text: text,
                    pageIndex: pageIndex,
                    tokenUnit: tokenUnit,
                    chunking: chunking,
                    strategy: strategy
                )

                await yielder.yield(
                    processedChunks,
                    progress: progress,
                    to: continuation
                )
                try Task.checkCancellation()
            }
        }
    }

    private func processPDFPage(
        text: String,
        pageIndex: Int,
        tokenUnit: NLTokenUnit,
        chunking: ChunkingConfiguration,
        strategy: FileProcessingStrategy
    ) async throws -> [ChunkData] {
        let chunks: [String] = RagTokenizer().tokenizeAndChunk(
            text,
            using: tokenUnit,
            chunking: chunking
        )
        return try await processChunks(
            chunks,
            pageIndex: pageIndex,
            strategy: strategy
        )
    }

    private func pageText(
        document: PDFDocument,
        pageIndex: Int
    ) -> String? {
        guard
            let page = document.page(at: pageIndex),
            let text = page.string
        else {
            kLogger.warning(
                "Could not extract text from page \(pageIndex + 1, privacy: .public)"
            )
            return nil
        }

        return text
    }
}
