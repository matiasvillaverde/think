import Foundation

protocol CLIOutputting: Sendable {
    func write(_ text: String)
    func writeInline(_ text: String)
}

struct StdoutOutput: CLIOutputting {
    func write(_ text: String) {
        print(text)
    }

    func writeInline(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            return
        }
        FileHandle.standardOutput.write(data)
    }
}

struct StderrOutput: CLIOutputting {
    func write(_ text: String) {
        guard let data = (text + "\n").data(using: .utf8) else {
            return
        }
        FileHandle.standardError.write(data)
    }

    func writeInline(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            return
        }
        FileHandle.standardError.write(data)
    }
}

final class BufferOutput: CLIOutputting, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var lines: [String] = []
    private(set) var inline: [String] = []

    func write(_ text: String) {
        lock.lock()
        defer { lock.unlock() }
        lines.append(text)
    }

    func writeInline(_ text: String) {
        lock.lock()
        defer { lock.unlock() }
        inline.append(text)
    }
}

struct CLIMessage: Encodable, Sendable {
    let type: String
    let message: String

    init(_ message: String, type: String = "message") {
        self.type = type
        self.message = message
    }
}

struct CLIStreamChunk: Encodable, Sendable {
    let type: String
    let text: String

    init(text: String) {
        type = "stream"
        self.text = text
    }
}

struct CLIOutput: Sendable {
    private let writer: CLIOutputting
    private let format: CLIOutputFormat

    init(writer: CLIOutputting, format: CLIOutputFormat) {
        self.writer = writer
        self.format = format
    }

    var supportsStreaming: Bool {
        format == .text || format == .jsonLines
    }

    func emit(_ message: String) {
        emit(CLIMessage(message), fallback: message)
    }

    func stream(_ text: String) {
        switch format {
        case .text:
            writer.writeInline(text)
        case .jsonLines:
            emitLine(CLIStreamChunk(text: text))
        case .json:
            return
        }
    }

    func emit<T: Encodable>(_ value: T, fallback: String) {
        switch format {
        case .text:
            writer.write(fallback)
        case .json:
            writer.write(encode(value, pretty: true) ?? fallback)
        case .jsonLines:
            writer.write(encode(value, pretty: false) ?? fallback)
        }
    }

    private func emitLine<T: Encodable>(_ value: T) {
        if let line = encode(value, pretty: false) {
            writer.write(line)
        }
    }

    private func encode<T: Encodable>(_ value: T, pretty: Bool) -> String? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
            let data = try encoder.encode(value)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
