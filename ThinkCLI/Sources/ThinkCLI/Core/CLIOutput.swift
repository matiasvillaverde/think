import Foundation

protocol CLIOutputting: Sendable {
    func write(_ text: String)
}

struct StdoutOutput: CLIOutputting {
    func write(_ text: String) {
        print(text)
    }
}

final class BufferOutput: CLIOutputting {
    private let lock = NSLock()
    private(set) var lines: [String] = []

    func write(_ text: String) {
        lock.lock()
        defer { lock.unlock() }
        lines.append(text)
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
