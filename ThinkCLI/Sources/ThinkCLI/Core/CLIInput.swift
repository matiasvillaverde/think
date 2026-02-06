import Foundation

protocol CLIInputting {
    func readLine(prompt: String) -> String?
}

struct StdInCLIInput: CLIInputting {
    func readLine(prompt: String) -> String? {
        if !prompt.isEmpty,
           let data = (prompt + " ").data(using: .utf8) {
            FileHandle.standardOutput.write(data)
        }
        return Swift.readLine()
    }
}
