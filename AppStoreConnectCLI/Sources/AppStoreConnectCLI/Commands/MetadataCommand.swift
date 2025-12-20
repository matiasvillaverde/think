import Foundation
import ArgumentParser

/// Command for app metadata operations
struct MetadataCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "metadata",
        abstract: "Manage app metadata in App Store Connect",
        discussion: """
        Download and upload app metadata including descriptions, keywords,
        categories, and other App Store information.
        """,
        subcommands: [
            DownloadMetadataCommand.self,
            UploadMetadataCommand.self,
            ListAppsCommand.self
        ]
    )
}

// MARK: - Download Metadata Subcommand
struct DownloadMetadataCommand: AuthenticatedCommand {
    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "Download app metadata from App Store Connect"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Option(name: .shortAndLong, help: "Bundle ID of the app")
    var bundleId: String
    
    @Option(name: .shortAndLong, help: "Output directory for metadata files")
    var output: String = "./metadata"
    
    @Option(name: .long, help: "Platform (iOS, macOS, visionOS)")
    var platform: String = "iOS"
    
    func executeAuthenticated(
        authService: AppStoreConnectAuthenticationService,
        context: CLIContext
    ) async throws {
        CLIOutput.progress("Downloading metadata for \(bundleId)...", 
                          colored: !globalOptions.noColor)
        
        let metadataService = MetadataService(authService: authService)
        
        do {
            try await metadataService.downloadMetadata(
                bundleId: bundleId,
                platform: platform,
                outputDirectory: output
            )
        } catch let error as AppStoreConnectError {
            throw error
        } catch {
            throw AppStoreConnectError.metadataDownloadFailed(
                reason: error.localizedDescription
            )
        }
    }
}

// MARK: - Upload Metadata Subcommand
struct UploadMetadataCommand: AuthenticatedCommand {
    static let configuration = CommandConfiguration(
        commandName: "upload",
        abstract: "Upload app metadata to App Store Connect"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Option(name: .shortAndLong, help: "Bundle ID of the app")
    var bundleId: String
    
    @Option(name: .shortAndLong, help: "Directory containing metadata files")
    var input: String = "./metadata"
    
    @Option(name: .long, help: "Platform (iOS, macOS, visionOS)")
    var platform: String = "iOS"
    
    @Flag(name: .long, help: "Skip validation before upload")
    var skipValidation: Bool = false
    
    func executeAuthenticated(
        authService: AppStoreConnectAuthenticationService,
        context: CLIContext
    ) async throws {
        CLIOutput.progress("Uploading metadata for \(bundleId)...", 
                          colored: !globalOptions.noColor)
        
        let metadataService = MetadataService(authService: authService)
        
        do {
            try await metadataService.uploadMetadata(
                bundleId: bundleId,
                platform: platform,
                inputDirectory: input,
                skipValidation: skipValidation
            )
        } catch let error as AppStoreConnectError {
            throw error
        } catch {
            throw AppStoreConnectError.metadataUploadFailed(
                reason: error.localizedDescription
            )
        }
    }
}

// MARK: - List Apps Subcommand
struct ListAppsCommand: AuthenticatedCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all apps in App Store Connect"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Option(name: .long, help: "Filter by platform (iOS, macOS, visionOS)")
    var platform: String?
    
    @Flag(name: .long, help: "Show detailed information")
    var detailed: Bool = false
    
    func executeAuthenticated(
        authService: AppStoreConnectAuthenticationService,
        context: CLIContext
    ) async throws {
        CLIOutput.progress("Fetching apps from App Store Connect...", 
                          colored: !globalOptions.noColor)
        
        let metadataService = MetadataService(authService: authService)
        
        do {
            let apps = try await metadataService.listApps(platform: platform)
            
            if apps.isEmpty {
                CLIOutput.warning("No apps found", colored: !globalOptions.noColor)
                return
            }
            
            CLIOutput.success("Found \(apps.count) app(s)", colored: !globalOptions.noColor)
            CLIOutput.info("", colored: !globalOptions.noColor) // Empty line
            
            for app in apps {
                if detailed {
                    CLIOutput.info("App: \(app.name)", colored: !globalOptions.noColor)
                    CLIOutput.info("  Bundle ID: \(app.bundleId)", colored: !globalOptions.noColor)
                    CLIOutput.info("  SKU: \(app.sku)", colored: !globalOptions.noColor)
                    CLIOutput.info("  Primary Locale: \(app.primaryLocale)", 
                                  colored: !globalOptions.noColor)
                    CLIOutput.info("  ID: \(app.id)", colored: !globalOptions.noColor)
                    CLIOutput.info("", colored: !globalOptions.noColor) // Empty line
                } else {
                    CLIOutput.info("\(app.bundleId) - \(app.name)", colored: !globalOptions.noColor)
                }
            }
        } catch let error as AppStoreConnectError {
            throw error
        } catch {
            throw AppStoreConnectError.metadataDownloadFailed(
                reason: error.localizedDescription
            )
        }
    }
}
