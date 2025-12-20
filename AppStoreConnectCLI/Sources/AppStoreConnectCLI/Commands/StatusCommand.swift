import Foundation
import ArgumentParser

/// Command to show authentication and connection status
struct StatusCommand: AuthenticatedCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show authentication and connection status",
        discussion: """
        Displays the current authentication status and validates the connection
        to App Store Connect API. This is useful for troubleshooting
        authentication issues.
        """
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Flag(name: .long, help: "Show detailed information")
    var detailed: Bool = false
    
    func executeAuthenticated(
        authService: AppStoreConnectAuthenticationService,
        context: CLIContext
    ) async throws {
        CLIOutput.section("App Store Connect Status", colored: !globalOptions.noColor)
        
        do {
            let config = try await context.getConfiguration()
            let isAuthenticated = await authService.isAuthenticated
            
            if isAuthenticated {
                CLIOutput.success("Authentication successful", colored: !globalOptions.noColor)
            } else {
                CLIOutput.error("Authentication failed", colored: !globalOptions.noColor)
                return
            }
            
            // Basic status information
            CLIOutput.keyValue("Key ID", config.keyID, colored: !globalOptions.noColor)
            CLIOutput.keyValue("Issuer ID", config.issuerID, colored: !globalOptions.noColor)
            
            if let teamID = config.teamID {
                CLIOutput.keyValue("Team ID", teamID, colored: !globalOptions.noColor)
            }
            
            // Connection test
            CLIOutput.progress("Testing API connection...", colored: !globalOptions.noColor)
            let connectionValid = try await authService.validateAuthentication()
            
            if connectionValid {
                CLIOutput.success("API connection is working", colored: !globalOptions.noColor)
            } else {
                CLIOutput.error("API connection failed", colored: !globalOptions.noColor)
                return
            }
            
            // Detailed information if requested
            if detailed {
                CLIOutput.section("Configuration Details", colored: !globalOptions.noColor)
                CLIOutput.keyValue("Timeout", "\(config.timeout)s", colored: !globalOptions.noColor)
                CLIOutput.keyValue("Retry Attempts", "\(config.retryAttempts)", 
                                 colored: !globalOptions.noColor)
                CLIOutput.keyValue("Verbose Logging", 
                                 config.verboseLogging ? "Enabled" : "Disabled",
                                 colored: !globalOptions.noColor)
                
                if let keyPath = config.privateKeyPath {
                    CLIOutput.keyValue("Private Key Path", keyPath, colored: !globalOptions.noColor)
                } else {
                    CLIOutput.keyValue("Private Key Source", "Environment Variable", 
                                     colored: !globalOptions.noColor)
                }
                
                // Environment variables check
                CLIOutput.section("Environment Variables", colored: !globalOptions.noColor)
                let envVars = [
                    ("APPSTORE_KEY_ID", ProcessInfo.processInfo.environment["APPSTORE_KEY_ID"]),
                    ("APPSTORE_ISSUER_ID", 
                     ProcessInfo.processInfo.environment["APPSTORE_ISSUER_ID"]),
                    ("APPSTORE_P8_KEY", 
                     ProcessInfo.processInfo.environment["APPSTORE_P8_KEY"] != nil ? 
                     "Set (hidden)" : nil),
                    ("APPSTORE_KEY_PATH", 
                     ProcessInfo.processInfo.environment["APPSTORE_KEY_PATH"]),
                    ("TEAM_ID", ProcessInfo.processInfo.environment["TEAM_ID"])
                ]
                
                for (name, value) in envVars {
                    let displayValue = value ?? "Not set"
                    CLIOutput.keyValue(name, displayValue, colored: !globalOptions.noColor)
                }
            }
            
        } catch {
            CLIOutput.error("Failed to get status: \(error.localizedDescription)", 
                          colored: !globalOptions.noColor)
            throw ExitCode.failure
        }
    }
}
