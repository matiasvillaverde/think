import ArgumentParser
import Foundation

@main
struct ThinkCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "think",
        abstract: "Think CLI for chat, models, tools, RAG, and gateway operations.",
        subcommands: [
            GatewayCommand.self,
            ChatCommand.self,
            ModelsCommand.self,
            ToolsCommand.self,
            RagCommand.self,
            SkillsCommand.self,
            PersonalityCommand.self,
            SchedulesCommand.self,
            StatusCommand.self,
            DoctorCommand.self,
            ConfigCommand.self,
            OnboardCommand.self
        ]
    )

    @OptionGroup
    var global: GlobalOptions

    static func main() async {
        do {
            var command = try parseAsRoot()
            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
        } catch {
            handle(error)
        }
    }

    private static func handle(_ error: Error) -> Never {
        if let cliError = error as? CLIError {
            StderrOutput().write(cliError.message)
            Foundation.exit(cliError.exitCode.rawValue)
        }

        let message = fullMessage(for: error)
        let exitCode = exitCode(for: error)
        let writer: CLIOutputting = exitCode == .success
            ? StdoutOutput()
            : StderrOutput()
        if !message.isEmpty {
            writer.write(message)
        }
        Foundation.exit(exitCode.rawValue)
    }
}
