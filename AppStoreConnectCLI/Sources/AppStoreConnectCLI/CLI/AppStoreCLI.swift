import Foundation
import ArgumentParser

/// Main CLI entry point for App Store Connect operations
@main
struct AppStoreCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app-store-cli",
        abstract: "A Swift CLI for App Store Connect operations",
        discussion: """
        This CLI provides access to App Store Connect operations using the official API.
        It replaces broken authentication scripts with a reliable Swift implementation.
        
        Authentication can be provided via environment variables or configuration file:
        - APPSTORE_KEY_ID or APP_STORE_CONNECT_API_KEY_ID
        - APPSTORE_ISSUER_ID or APP_STORE_CONNECT_API_KEY_ISSUER_ID
        - APPSTORE_P8_KEY or APP_STORE_CONNECT_API_KEY_PATH
        - TEAM_ID or DEVELOPMENT_TEAM (optional)
        """,
        version: "1.0.0",
        subcommands: [
            MetadataCommand.self,
            VersionCommand.self,
            BuildCommand.self,
            StatusCommand.self,
            ReviewsCommand.self
        ],
        defaultSubcommand: StatusCommand.self
    )
    
    // MARK: - Global Options
    @Option(name: .shortAndLong, help: "Configuration file path")
    var config: String?
    
    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose: Bool = false
    
    @Flag(name: .long, help: "Disable colored output")
    var noColor: Bool = false
    
    // MARK: - Execution
    func run() async throws {
        // This should never be called directly since we have a default subcommand
        // swiftlint:disable:next no_print_statements
        print("Use 'app-store-cli --help' to see available commands")
    }
}

// MARK: - Global CLI Context
/// Shared context for CLI operations
actor CLIContext {
    private var authenticationService: AppStoreConnectAuthenticationService?
    private var configuration: Configuration?
    
    func getAuthenticationService() throws -> AppStoreConnectAuthenticationService {
        guard let service = authenticationService else {
            throw AppStoreConnectError.authenticationFailed(
                reason: "Authentication service not initialized"
            )
        }
        return service
    }
    
    func initializeAuthentication(
        configPath: String?,
        verbose: Bool
    ) async throws -> AppStoreConnectAuthenticationService {
        let config: Configuration
        
        if let configPath = configPath {
            config = try Configuration.fromFile(at: configPath)
        } else {
            config = try Configuration.fromEnvironment()
        }
        
        // Apply verbose setting from CLI if not set in config
        let finalConfig = try Configuration(
            keyID: config.keyID,
            issuerID: config.issuerID,
            privateKeyPath: config.privateKeyPath,
            privateKeyContent: config.privateKeyContent,
            teamID: config.teamID,
            timeout: config.timeout,
            retryAttempts: config.retryAttempts,
            verboseLogging: verbose || config.verboseLogging
        )
        
        let service = AppStoreConnectAuthenticationService()
        try await service.authenticate(with: finalConfig)
        
        self.authenticationService = service
        self.configuration = finalConfig
        
        return service
    }
    
    func getConfiguration() throws -> Configuration {
        guard let config = configuration else {
            throw AppStoreConnectError.configurationError(
                message: "Configuration not initialized"
            )
        }
        return config
    }
}

// MARK: - Base Command Protocol
/// Protocol for commands that require authentication
protocol AuthenticatedCommand: AsyncParsableCommand {
    var globalOptions: GlobalOptions { get }
    func executeAuthenticated(
        authService: AppStoreConnectAuthenticationService,
        context: CLIContext
    ) async throws
}

extension AuthenticatedCommand {
    func run() async throws {
        let context = CLIContext()
        
        do {
            let authService = try await context.initializeAuthentication(
                configPath: globalOptions.config,
                verbose: globalOptions.verbose
            )
            
            try await executeAuthenticated(authService: authService, context: context)
            
        } catch let error as AppStoreConnectError {
            CLIOutput.error(error.localizedDescription, colored: !globalOptions.noColor)
            if let recovery = error.recoverySuggestion {
                CLIOutput.info("Suggestion: \(recovery)", colored: !globalOptions.noColor)
            }
            throw ExitCode.failure
        } catch {
            CLIOutput.error("Unexpected error: \(error.localizedDescription)", 
                          colored: !globalOptions.noColor)
            throw ExitCode.failure
        }
    }
}

/// Shared global options for all commands
struct GlobalOptions: ParsableArguments {
    @Option(name: .shortAndLong, help: "Configuration file path")
    var config: String?
    
    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose: Bool = false
    
    @Flag(name: .long, help: "Disable colored output")
    var noColor: Bool = false
}
