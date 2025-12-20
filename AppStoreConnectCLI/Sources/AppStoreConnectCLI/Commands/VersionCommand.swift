import Foundation
import ArgumentParser
@preconcurrency import AppStoreConnect_Swift_SDK

/// Command for app version management
struct VersionCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Manage app versions in App Store Connect",
        discussion: """
        Create, update, and manage app versions including version strings,
        build numbers, and release states.
        """,
        subcommands: [
            CreateVersionCommand.self,
            UpdateVersionCommand.self,
            ListVersionsCommand.self,
            DeleteVersionCommand.self
        ]
    )
}

// MARK: - Create Version Subcommand
struct CreateVersionCommand: AuthenticatedCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new app version"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Option(name: .shortAndLong, help: "Bundle ID of the app")
    var bundleId: String
    
    @Option(name: .customLong("version-string"), help: "Version string (e.g., 1.0.0)")
    var versionString: String
    
    @Option(name: .long, help: "Platform (iOS, macOS, visionOS)")
    var platform: String = "iOS"
    
    @Flag(name: .long, help: "Create as draft version")
    var draft: Bool = false
    
    func executeAuthenticated(
        authService: AppStoreConnectAuthenticationService,
        context: CLIContext
    ) async throws {
        CLIOutput.progress("Creating version \(versionString) for \(bundleId)...", 
                          colored: !globalOptions.noColor)
        
        do {
            let versionService = VersionService(authService: authService)
            let version = try await versionService.createVersion(
                bundleId: bundleId,
                versionString: versionString,
                platform: platform,
                isDraft: draft
            )
            
            CLIOutput.success("✓ Version \(versionString) created successfully", 
                            colored: !globalOptions.noColor)
            CLIOutput.info("  Platform: \(platform)", colored: !globalOptions.noColor)
            CLIOutput.info("  Version ID: \(version.id)", colored: !globalOptions.noColor)
            CLIOutput.info(
                "  State: \(version.attributes?.appStoreState?.rawValue ?? "Unknown")", 
                colored: !globalOptions.noColor
            )
            
        } catch let error as AppStoreConnectError {
            switch error {
            case .versionAlreadyExists(let version, let platform):
                CLIOutput.success("✓ Version \(version) already exists for \(platform)", 
                                colored: !globalOptions.noColor)
                CLIOutput.info("  No action needed - version is ready", 
                             colored: !globalOptions.noColor)
                // Don't throw the error - treat as success
                return
            case .appNotFound(let bundleId):
                CLIOutput.error(
                    "App with bundle ID '\(bundleId)' not found", 
                    colored: !globalOptions.noColor
                )
            case .invalidPlatform(let platform):
                CLIOutput.error(
                    "Invalid platform '\(platform)'. Valid values: iOS, macOS, visionOS", 
                    colored: !globalOptions.noColor
                )
            case .platformNotSupported(let platform, let bundleId):
                CLIOutput.warning(
                    "Platform \(platform) is not supported for app \(bundleId)", 
                    colored: !globalOptions.noColor
                )
                CLIOutput.info(
                    "  The app may not be configured for \(platform) in App Store Connect", 
                    colored: !globalOptions.noColor
                )
                // Don't throw the error - treat as informational
                return
            default:
                CLIOutput.error("Failed to create version: \(error.localizedDescription)", 
                              colored: !globalOptions.noColor)
            }
            throw error
        } catch {
            CLIOutput.error("Failed to create version: \(error.localizedDescription)", 
                          colored: !globalOptions.noColor)
            throw error
        }
    }
}

// MARK: - Update Version Subcommand
struct UpdateVersionCommand: AuthenticatedCommand {
    static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Update an existing app version"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Option(name: .shortAndLong, help: "Bundle ID of the app")
    var bundleId: String
    
    @Option(name: .customLong("version-string"), help: "Version string to update")
    var versionString: String
    
    @Option(name: .long, help: "Platform (iOS, macOS, visionOS)")
    var platform: String = "iOS"
    
    @Option(name: .long, help: "Update copyright text")
    var copyright: String?
    
    @Option(name: .long, help: "Update earliest release date (YYYY-MM-DD)")
    var releaseDate: String?
    
    func executeAuthenticated(
        authService: AppStoreConnectAuthenticationService,
        context: CLIContext
    ) async throws {
        CLIOutput.progress("Updating version \(versionString) for \(bundleId)...", 
                          colored: !globalOptions.noColor)
        
        do {
            let versionService = VersionService(authService: authService)
            
            // First, find the version to update
            let versions = try await versionService.listVersions(
                bundleId: bundleId,
                platform: platform
            )
            
            guard let versionToUpdate = versions.first(where: { 
                $0.attributes?.versionString == versionString 
            }) else {
                CLIOutput.error(
                    "Version \(versionString) not found for \(bundleId) on \(platform)", 
                    colored: !globalOptions.noColor
                )
                throw AppStoreConnectError.versionNotFound(versionId: versionString)
            }
            
            try await versionService.updateVersion(
                versionId: versionToUpdate.id,
                copyright: copyright,
                releaseDate: releaseDate
            )
            
            CLIOutput.success("✓ Version \(versionString) updated successfully", 
                            colored: !globalOptions.noColor)
            
            if let copyright = copyright {
                CLIOutput.info("  Updated copyright: \(copyright)", colored: !globalOptions.noColor)
            }
            if let releaseDate = releaseDate {
                CLIOutput.info(
                    "  Updated release date: \(releaseDate)", 
                    colored: !globalOptions.noColor
                )
            }
            
        } catch let error as AppStoreConnectError {
            switch error {
            case .appNotFound(let bundleId):
                CLIOutput.error(
                    "App with bundle ID '\(bundleId)' not found", 
                    colored: !globalOptions.noColor
                )
            case .versionNotFound:
                CLIOutput.error(
                    "Version \(versionString) not found for \(bundleId) on \(platform)", 
                    colored: !globalOptions.noColor
                )
            case .invalidPlatform(let platform):
                CLIOutput.error(
                    "Invalid platform '\(platform)'. Valid values: iOS, macOS, visionOS", 
                    colored: !globalOptions.noColor
                )
            default:
                CLIOutput.error("Failed to update version: \(error.localizedDescription)", 
                              colored: !globalOptions.noColor)
            }
            throw error
        } catch {
            CLIOutput.error("Failed to update version: \(error.localizedDescription)", 
                          colored: !globalOptions.noColor)
            throw error
        }
    }
}

// MARK: - List Versions Subcommand
struct ListVersionsCommand: AuthenticatedCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List app versions"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Option(name: .shortAndLong, help: "Bundle ID of the app")
    var bundleId: String
    
    @Option(name: .long, help: "Platform (iOS, macOS, visionOS)")
    var platform: String = "iOS"
    
    @Flag(name: .long, help: "Show detailed information")
    var detailed: Bool = false
    
    func executeAuthenticated(
        authService: AppStoreConnectAuthenticationService,
        context: CLIContext
    ) async throws {
        CLIOutput.progress("Fetching versions for \(bundleId)...", 
                          colored: !globalOptions.noColor)
        
        do {
            let versionService = VersionService(authService: authService)
            let versions = try await versionService.listVersions(
                bundleId: bundleId,
                platform: platform
            )
            
            if versions.isEmpty {
                CLIOutput.info("No versions found for \(bundleId) on \(platform)", 
                             colored: !globalOptions.noColor)
                return
            }
            
            CLIOutput.success("✓ Found \(versions.count) version(s)", 
                            colored: !globalOptions.noColor)
            CLIOutput.info("", colored: !globalOptions.noColor)
            
            for version in versions {
                let versionString = version.attributes?.versionString ?? "Unknown"
                let state = version.attributes?.appStoreState?.rawValue ?? "Unknown"
                let platform = version.attributes?.platform?.rawValue ?? "Unknown"
                
                CLIOutput.info("Version: \(versionString)", colored: !globalOptions.noColor)
                CLIOutput.info("  ID: \(version.id)", colored: !globalOptions.noColor)
                CLIOutput.info("  Platform: \(platform)", colored: !globalOptions.noColor)
                CLIOutput.info("  State: \(state)", colored: !globalOptions.noColor)
                
                if detailed {
                    if let copyright = version.attributes?.copyright {
                        CLIOutput.info("  Copyright: \(copyright)", colored: !globalOptions.noColor)
                    }
                    if let createdDate = version.attributes?.createdDate {
                        CLIOutput.info("  Created: \(createdDate)", colored: !globalOptions.noColor)
                    }
                    if let releaseType = version.attributes?.releaseType?.rawValue {
                        CLIOutput.info(
                            "  Release Type: \(releaseType)", 
                            colored: !globalOptions.noColor
                        )
                    }
                }
                CLIOutput.info("", colored: !globalOptions.noColor)
            }
            
        } catch let error as AppStoreConnectError {
            switch error {
            case .appNotFound(let bundleId):
                CLIOutput.error(
                    "App with bundle ID '\(bundleId)' not found", 
                    colored: !globalOptions.noColor
                )
            case .invalidPlatform(let platform):
                CLIOutput.error(
                    "Invalid platform '\(platform)'. Valid values: iOS, macOS, visionOS", 
                    colored: !globalOptions.noColor
                )
            default:
                CLIOutput.error("Failed to fetch versions: \(error.localizedDescription)", 
                              colored: !globalOptions.noColor)
            }
            throw error
        } catch {
            CLIOutput.error("Failed to fetch versions: \(error.localizedDescription)", 
                          colored: !globalOptions.noColor)
            throw error
        }
    }
}

// MARK: - Delete Version Subcommand
struct DeleteVersionCommand: AuthenticatedCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete an app version"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Option(name: .shortAndLong, help: "Bundle ID of the app")
    var bundleId: String
    
    @Option(name: .customLong("version-string"), help: "Version string to delete")
    var versionString: String
    
    @Option(name: .long, help: "Platform (iOS, macOS, visionOS)")
    var platform: String = "iOS"
    
    @Flag(name: .long, help: "Force deletion without confirmation")
    var force: Bool = false
    
    func executeAuthenticated(
        authService: AppStoreConnectAuthenticationService,
        context: CLIContext
    ) async throws {
        if !force {
            CLIOutput.warning("This will permanently delete version \(versionString)", 
                            colored: !globalOptions.noColor)
            CLIOutput.text("Type 'yes' to confirm: ")
            
            guard let input = readLine(), input.lowercased() == "yes" else {
                CLIOutput.info("Operation cancelled", colored: !globalOptions.noColor)
                return
            }
        }
        
        CLIOutput.progress("Deleting version \(versionString) for \(bundleId)...", 
                          colored: !globalOptions.noColor)
        
        do {
            let versionService = VersionService(authService: authService)
            
            // First, find the version to delete
            let versions = try await versionService.listVersions(
                bundleId: bundleId,
                platform: platform
            )
            
            guard let versionToDelete = versions.first(where: { 
                $0.attributes?.versionString == versionString 
            }) else {
                CLIOutput.error(
                    "Version \(versionString) not found for \(bundleId) on \(platform)", 
                    colored: !globalOptions.noColor
                )
                throw AppStoreConnectError.versionNotFound(versionId: versionString)
            }
            
            try await versionService.deleteVersion(versionId: versionToDelete.id)
            
            CLIOutput.success("✓ Version \(versionString) deleted successfully", 
                            colored: !globalOptions.noColor)
            
        } catch let error as AppStoreConnectError {
            switch error {
            case .appNotFound(let bundleId):
                CLIOutput.error(
                    "App with bundle ID '\(bundleId)' not found", 
                    colored: !globalOptions.noColor
                )
            case .versionNotFound:
                CLIOutput.error(
                    "Version \(versionString) not found for \(bundleId) on \(platform)", 
                    colored: !globalOptions.noColor
                )
            case .invalidPlatform(let platform):
                CLIOutput.error(
                    "Invalid platform '\(platform)'. Valid values: iOS, macOS, visionOS", 
                    colored: !globalOptions.noColor
                )
            default:
                CLIOutput.error("Failed to delete version: \(error.localizedDescription)", 
                              colored: !globalOptions.noColor)
            }
            throw error
        } catch {
            CLIOutput.error("Failed to delete version: \(error.localizedDescription)", 
                          colored: !globalOptions.noColor)
            throw error
        }
    }
}
