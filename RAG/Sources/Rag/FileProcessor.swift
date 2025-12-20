import Abstractions
import Foundation
import NaturalLanguage
import PDFKit

internal struct FileProcessor {
    func processFile(
        _ url: URL,
        fileType: SupportedFileType,
        tokenUnit: NLTokenUnit,
        chunking: ChunkingConfiguration,
        strategy: FileProcessingStrategy
    ) -> AsyncThrowingStream<([ChunkData], Progress), Error> {
        switch fileType {
        case .pdf:
            return processPDFFileAsync(
                url,
                tokenUnit: tokenUnit,
                chunking: chunking,
                strategy: strategy
            )

        case .text, .markdown:
            return processTextFileAsync(
                url,
                tokenUnit: tokenUnit,
                chunking: chunking,
                strategy: strategy
            )

        case .json:
            return processJSONFileAsync(
                url,
                tokenUnit: tokenUnit,
                chunking: chunking,
                strategy: strategy
            )

        case .csv:
            return processCSVFileAsync(
                url,
                tokenUnit,
                chunking: chunking,
                strategy: strategy
            )

        case .docx:
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: FileProcessorError.unsupportedOperation("docx"))
            }
        }
    }

    func processTextAsync(
        _ text: String,
        tokenUnit: NLTokenUnit,
        chunking: ChunkingConfiguration,
        strategy: FileProcessingStrategy
    ) -> AsyncThrowingStream<([ChunkData], Progress), Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let progress: Progress = Progress(
                        totalUnitCount: Constants.defaultProgressUnitCount
                    )
                    progress.kind = .file

                    let chunks: [String] = RagTokenizer().tokenizeAndChunk(
                        text,
                        using: tokenUnit,
                        chunking: chunking
                    )
                    let processedChunks: [ChunkData] = try await processChunks(
                        chunks,
                        pageIndex: Constants.initialPageIndex,
                        strategy: strategy
                    )

                    progress.completedUnitCount = Constants.defaultProgressUnitCount
                    continuation.yield((processedChunks, progress))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func processCSVFileAsync(
        _ url: URL,
        _: NLTokenUnit,
        chunking: ChunkingConfiguration,
        strategy: FileProcessingStrategy
    ) -> AsyncThrowingStream<([ChunkData], Progress), Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result: ([ChunkData], Progress) = try await processCSVFileContent(
                        url: url,
                        chunking: chunking,
                        strategy: strategy
                    )
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func processCSVFileContent(
        url: URL,
        chunking: ChunkingConfiguration,
        strategy: FileProcessingStrategy
    ) async throws -> ([ChunkData], Progress) {
        guard url.startAccessingSecurityScopedResource() else {
            throw FileProcessorError.couldNotReadFile("We don't have access \(url)")
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        let progress: Progress = Progress(
            totalUnitCount: Constants.defaultProgressUnitCount
        )
        progress.kind = .file
        progress.fileOperationKind = .duplicating

        let text: String = try String(contentsOf: url, encoding: .utf8)
        let lines: [String] = text.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        let chunks: [String] = RagTokenizer().chunkTokens(lines, chunking: chunking)

        let processedChunks: [ChunkData] = try await processChunks(
            chunks,
            pageIndex: Constants.initialPageIndex,
            strategy: strategy
        )

        progress.completedUnitCount = Constants.defaultProgressUnitCount
        return (processedChunks, progress)
    }

    private func processTextFileAsync(
        _ url: URL,
        tokenUnit: NLTokenUnit,
        chunking: ChunkingConfiguration,
        strategy: FileProcessingStrategy
    ) -> AsyncThrowingStream<([ChunkData], Progress), Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result: ([ChunkData], Progress) = try await processTextFileContent(
                        url: url,
                        tokenUnit: tokenUnit,
                        chunking: chunking,
                        strategy: strategy
                    )
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func processTextFileContent(
        url: URL,
        tokenUnit: NLTokenUnit,
        chunking: ChunkingConfiguration,
        strategy: FileProcessingStrategy
    ) async throws -> ([ChunkData], Progress) {
        guard url.startAccessingSecurityScopedResource() else {
            throw FileProcessorError.couldNotReadFile("We don't have access \(url)")
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        let progress: Progress = Progress(
            totalUnitCount: Constants.defaultProgressUnitCount
        )
        progress.kind = .file
        progress.fileOperationKind = .duplicating

        let text: String = try String(contentsOf: url, encoding: .utf8)
        guard !text.isEmpty else {
            throw FileProcessorError.fileISEmpty
        }

        let chunks: [String] = RagTokenizer().tokenizeAndChunk(
            text,
            using: tokenUnit,
            chunking: chunking
        )
        let processedChunks: [ChunkData] = try await processChunks(
            chunks,
            pageIndex: Constants.initialPageIndex,
            strategy: strategy
        )

        progress.completedUnitCount = Constants.defaultProgressUnitCount
        return (processedChunks, progress)
    }

    private func processJSONFileAsync(
        _ url: URL,
        tokenUnit: NLTokenUnit,
        chunking: ChunkingConfiguration,
        strategy: FileProcessingStrategy
    ) -> AsyncThrowingStream<([ChunkData], Progress), Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result: ([ChunkData], Progress) = try await processJSONData(
                        from: url,
                        tokenUnit: tokenUnit,
                        chunking: chunking,
                        strategy: strategy
                    )
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func processJSONData(
        from url: URL,
        tokenUnit: NLTokenUnit,
        chunking: ChunkingConfiguration,
        strategy: FileProcessingStrategy
    ) async throws -> ([ChunkData], Progress) {
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            throw FileProcessorError.couldNotReadFile("We don't have access \(url)")
        }

        defer {
            // Make sure we release the security-scoped resource when done
            url.stopAccessingSecurityScopedResource()
        }

        let progress: Progress = Progress(totalUnitCount: Constants.defaultProgressUnitCount)
        progress.kind = .file
        progress.fileOperationKind = .duplicating

        let data: Data = try Data(contentsOf: url)
        guard
            let json: [String: Any] = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw FileProcessorError.invalidJSONFormat
        }

        let text: Data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        let chunks: [String] = RagTokenizer().tokenizeAndChunk(
            String(data: text, encoding: .utf8) ?? "",
            using: tokenUnit,
            chunking: chunking
        )

        let processedChunks: [ChunkData] = try await processChunks(
            chunks,
            pageIndex: Constants.initialPageIndex,
            strategy: strategy
        )

        progress.completedUnitCount = Constants.defaultProgressUnitCount
        return (processedChunks, progress)
    }

    internal func processChunks(
        _ chunks: [String],
        pageIndex: Int,
        strategy: FileProcessingStrategy
    ) async throws -> [ChunkData] {
        try await withThrowingTaskGroup(of: ChunkData.self) { group in
            var processedChunks: [ChunkData] = [ChunkData]()

            for (offset, chunk) in chunks.enumerated() {
                group.addTask {
                    let keywords: String =
                        strategy == .extractKeywords
                        ? RagTokenizer().extractKeywords(from: chunk) : ""
                    return ChunkData(
                        text: chunk,
                        keywords: keywords,
                        pageIndex: pageIndex,
                        localChunkIndex: offset
                    )
                }
            }

            for try await chunk in group {
                processedChunks.append(chunk)
            }

            return processedChunks
        }
    }
}
