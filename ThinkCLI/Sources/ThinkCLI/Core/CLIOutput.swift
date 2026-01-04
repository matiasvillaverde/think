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

struct CLIOutput: Sendable {
    private let writer: CLIOutputting
    private let json: Bool
    private let encoder: JSONEncoder

    init(writer: CLIOutputting, json: Bool) {
        self.writer = writer
        self.json = json
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    func emit(_ message: String) {
        writer.write(message)
    }

    func stream(_ text: String) {
        writer.writeInline(text)
    }

    func emit<T: Encodable>(_ value: T, fallback: String) {
        guard json else {
            writer.write(fallback)
            return
        }
        do {
            let data = try encoder.encode(value)
            if let string = String(data: data, encoding: .utf8) {
                writer.write(string)
            } else {
                writer.write(fallback)
            }
        } catch {
            writer.write(fallback)
        }
    }
}
