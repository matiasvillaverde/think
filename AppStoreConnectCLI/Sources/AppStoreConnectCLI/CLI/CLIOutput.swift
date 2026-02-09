import Foundation

/// Utility for consistent CLI output formatting
public struct CLIOutput {
    // MARK: - Output Sink
    @inline(__always)
    private static func writeStdout(_ message: String, terminator: String = "\n") {
        fputs(message + terminator, stdout)
    }

    @inline(__always)
    private static func writeStderr(_ message: String, terminator: String = "\n") {
        fputs(message + terminator, stderr)
    }

    // MARK: - ANSI Colors
    private static let red = "\u{001B}[31m"
    private static let green = "\u{001B}[32m"
    private static let yellow = "\u{001B}[33m"
    private static let blue = "\u{001B}[34m"
    private static let magenta = "\u{001B}[35m"
    private static let cyan = "\u{001B}[36m"
    private static let white = "\u{001B}[37m"
    private static let bold = "\u{001B}[1m"
    private static let reset = "\u{001B}[0m"
    
    // MARK: - Output Methods
    /// Print a success message
    public static func success(_ message: String, colored: Bool = true) {
        let prefix = colored ? "\(green)✓\(reset)" : "✓"
        writeStdout("\(prefix) \(message)")
    }
    
    /// Print an error message
    public static func error(_ message: String, colored: Bool = true) {
        let prefix = colored ? "\(red)✗\(reset)" : "✗"
        writeStderr("\(prefix) \(message)")
    }
    
    /// Print a warning message
    public static func warning(_ message: String, colored: Bool = true) {
        let prefix = colored ? "\(yellow)⚠\(reset)" : "⚠"
        writeStdout("\(prefix) \(message)")
    }
    
    /// Print an info message
    public static func info(_ message: String, colored: Bool = true) {
        let prefix = colored ? "\(blue)ℹ\(reset)" : "ℹ"
        writeStdout("\(prefix) \(message)")
    }
    
    /// Print a progress message
    public static func progress(_ message: String, colored: Bool = true) {
        let prefix = colored ? "\(cyan)→\(reset)" : "→"
        writeStdout("\(prefix) \(message)")
    }
    
    /// Print a section header
    public static func section(_ title: String, colored: Bool = true) {
        let formatted = colored ? "\(bold)\(title)\(reset)" : title
        writeStdout("\n\(formatted)")
        if colored {
            writeStdout(String(repeating: "─", count: title.count))
        } else {
            writeStdout(String(repeating: "-", count: title.count))
        }
    }
    
    /// Print a key-value pair
    public static func keyValue(_ key: String, _ value: String, colored: Bool = true) {
        let keyFormatted = colored ? "\(bold)\(key):\(reset)" : "\(key):"
        writeStdout("  \(keyFormatted) \(value)")
    }
    
    /// Print a list item
    public static func listItem(_ item: String, colored: Bool = true) {
        let bullet = colored ? "\(white)•\(reset)" : "•"
        writeStdout("  \(bullet) \(item)")
    }
    
    /// Print raw text without formatting
    public static func text(_ message: String) {
        writeStdout(message)
    }
    
    /// Print a table with headers and rows
    public static func table(
        headers: [String], 
        rows: [[String]], 
        colored: Bool = true
    ) {
        guard !headers.isEmpty else { return }
        
        // Calculate column widths
        let columnCount = headers.count
        var columnWidths = headers.map { $0.count }
        
        for row in rows {
            for (index, cell) in row.enumerated() where index < columnCount {
                columnWidths[index] = max(columnWidths[index], cell.count)
            }
        }
        
        // Print headers
        let headerLine = headers.enumerated().map { index, header in
            header.padding(toLength: columnWidths[index], withPad: " ", startingAt: 0)
        }.joined(separator: " | ")
        
        if colored {
            writeStdout("\(bold)\(headerLine)\(reset)")
        } else {
            writeStdout(headerLine)
        }
        
        // Print separator
        let separator = columnWidths.map { width in
            String(repeating: "-", count: width)
        }.joined(separator: "-|-")
        writeStdout(separator)
        
        // Print rows
        for row in rows {
            let rowLine = row.enumerated().map { index, cell in
                let width = index < columnWidths.count ? columnWidths[index] : cell.count
                return cell.padding(toLength: width, withPad: " ", startingAt: 0)
            }.joined(separator: " | ")
            writeStdout(rowLine)
        }
    }
    
    /// Print a spinner with message (for long operations)
    public static func spinner(_ message: String, colored: Bool = true) {
        let spinChars = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
        let prefix = colored ? "\(cyan)\(spinChars[0])\(reset)" : spinChars[0]
        writeStdout("\(prefix) \(message)", terminator: "")
        fflush(stdout)
    }
}

// MARK: - Standard Error Extension
// Removed StandardError struct as we now use fputs directly
