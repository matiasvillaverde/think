import Abstractions
import Foundation

extension WorkspaceSkillLoader {
    private static let metadataSplitLimit: Int = 1
    private static let minimumKeyValueParts: Int = 2
    private static let toolsKey: String = "tools"
    private static let nameKey: String = "name"
    private static let descriptionKey: String = "description"
    private static let enabledKey: String = "enabled"
    private static let disabledKey: String = "disabled"

    internal func parseSkillFile(_ content: String) -> ParsedSkillFile {
        let normalized: String = content.replacingOccurrences(of: "\r\n", with: "\n")
        let lines: [Substring] = normalized.split(separator: "\n", omittingEmptySubsequences: false)

        guard let block = parseMetadataBlock(from: lines) else {
            let instructions: String = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
            return ParsedSkillFile(
                name: nil,
                description: nil,
                tools: [],
                isEnabled: true,
                instructions: instructions
            )
        }

        let metadata: ParsedSkillMetadata = parseMetadata(block.metadataLines)
        return ParsedSkillFile(
            name: metadata.name,
            description: metadata.description,
            tools: metadata.tools,
            isEnabled: metadata.isEnabled,
            instructions: block.body
        )
    }

    private func parseMetadataBlock(from lines: [Substring]) -> MetadataBlock? {
        guard isFrontMatterStart(lines.first) else {
            return nil
        }

        let section: MetadataSection = metadataSection(from: lines)
        let body: String = buildBody(from: lines, startIndex: section.bodyStart)
        return MetadataBlock(metadataLines: section.metadataLines, body: body)
    }

    private func isFrontMatterStart(_ line: Substring?) -> Bool {
        guard let line else {
            return false
        }
        return line.trimmingCharacters(in: .whitespacesAndNewlines) == "---"
    }

    private func metadataSection(from lines: [Substring]) -> MetadataSection {
        var metadataLines: [Substring] = []
        var endIndex: Int?

        for index in 1..<lines.count {
            let line: Substring = lines[index]
            if line.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                endIndex = index
                break
            }
            metadataLines.append(line)
        }

        let bodyStart: Int = (endIndex ?? 0) + 1
        return MetadataSection(metadataLines: metadataLines, bodyStart: bodyStart)
    }

    private func buildBody(from lines: [Substring], startIndex: Int) -> String {
        guard startIndex <= lines.count else {
            return ""
        }
        let bodyLines: [Substring] = Array(lines.dropFirst(startIndex))
        return bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseMetadata(_ lines: [Substring]) -> ParsedSkillMetadata {
        var accumulator: MetadataAccumulator = MetadataAccumulator()
        for line in lines {
            applyMetadataLine(line, accumulator: &accumulator)
        }

        return ParsedSkillMetadata(
            name: accumulator.name,
            description: accumulator.description,
            tools: accumulator.tools,
            isEnabled: accumulator.isEnabled
        )
    }

    private func applyMetadataLine(
        _ line: Substring,
        accumulator: inout MetadataAccumulator
    ) {
        let trimmed: String = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        if handleListItem(trimmed, accumulator: &accumulator) {
            return
        }

        accumulator.currentListKey = nil
        guard let keyValue = parseKeyValue(trimmed) else {
            return
        }

        handleKeyValue(key: keyValue.key, value: keyValue.value, accumulator: &accumulator)
    }

    private func handleListItem(
        _ trimmed: String,
        accumulator: inout MetadataAccumulator
    ) -> Bool {
        guard trimmed.hasPrefix("-"), accumulator.currentListKey == Self.toolsKey else {
            return false
        }

        let item: String = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
        if !item.isEmpty {
            accumulator.tools.append(item)
        }
        return true
    }

    private func parseKeyValue(_ line: String) -> (key: String, value: String)? {
        let parts: [Substring] = line.split(
            separator: ":",
            maxSplits: Self.metadataSplitLimit,
            omittingEmptySubsequences: false
        )
        guard parts.count >= Self.minimumKeyValueParts else {
            return nil
        }

        let key: String = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let value: String = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        return (key: key, value: value)
    }

    private func handleKeyValue(
        key: String,
        value: String,
        accumulator: inout MetadataAccumulator
    ) {
        if handleIdentityKey(key: key, value: value, accumulator: &accumulator) {
            return
        }
        if handleToolsKey(key: key, value: value, accumulator: &accumulator) {
            return
        }
        handleFlagKey(key: key, value: value, accumulator: &accumulator)
    }

    private func handleIdentityKey(
        key: String,
        value: String,
        accumulator: inout MetadataAccumulator
    ) -> Bool {
        switch key {
        case Self.nameKey:
            accumulator.name = value.isEmpty ? nil : value
            return true

        case Self.descriptionKey:
            accumulator.description = value.isEmpty ? nil : value
            return true

        default:
            return false
        }
    }

    private func handleToolsKey(
        key: String,
        value: String,
        accumulator: inout MetadataAccumulator
    ) -> Bool {
        guard key == Self.toolsKey else {
            return false
        }
        if value.isEmpty {
            accumulator.currentListKey = Self.toolsKey
            return true
        }

        accumulator.tools.append(contentsOf: parseToolsValue(value))
        return true
    }

    private func handleFlagKey(
        key: String,
        value: String,
        accumulator: inout MetadataAccumulator
    ) {
        let parsed: ParsedBool = parseBoolValue(value)
        switch key {
        case Self.enabledKey:
            if case let .value(flag) = parsed {
                accumulator.isEnabled = flag
            }

        case Self.disabledKey:
            if case let .value(flag) = parsed {
                accumulator.isEnabled = !flag
            }

        default:
            break
        }
    }

    private func parseToolsValue(_ value: String) -> [String] {
        if value.hasPrefix("["), value.hasSuffix("]") {
            let content: Substring = value.dropFirst().dropLast()
            let items: [Substring] = content.split(separator: ",")
            return items.map { item in
                item.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return [value]
    }

    private func parseBoolValue(_ value: String) -> ParsedBool {
        let normalized: String = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "true", "yes", "1":
            return .value(true)

        case "false", "no", "0":
            return .value(false)

        default:
            return .invalid
        }
    }

    internal struct ParsedSkillFile {
        internal let name: String?
        internal let description: String?
        internal let tools: [String]
        internal let isEnabled: Bool
        internal let instructions: String
    }

    internal struct MetadataBlock {
        internal let metadataLines: [Substring]
        internal let body: String
    }

    internal struct MetadataSection {
        internal let metadataLines: [Substring]
        internal let bodyStart: Int
    }

    internal struct MetadataAccumulator {
        internal var name: String?
        internal var description: String?
        internal var tools: [String] = []
        internal var isEnabled: Bool = true
        internal var currentListKey: String?
    }

    internal struct ParsedSkillMetadata {
        internal let name: String?
        internal let description: String?
        internal let tools: [String]
        internal let isEnabled: Bool
    }

    private enum ParsedBool {
        case value(Bool)
        case invalid
    }
}
