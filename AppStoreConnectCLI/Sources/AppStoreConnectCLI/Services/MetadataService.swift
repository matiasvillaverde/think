import Foundation
@preconcurrency import AppStoreConnect_Swift_SDK

/// Service for managing app metadata operations
public actor MetadataService {
    private let authService: AppStoreConnectAuthenticationService
    
    public init(authService: AppStoreConnectAuthenticationService) {
        self.authService = authService
    }
    
    // MARK: - List Apps
    public func listApps(platform: String? = nil) async throws -> [AppInfo] {
        let provider = try await authService.getAPIProvider()
        
        // Build request
        let request = APIEndpoint.v1.apps.get()
        
        // Add platform filter if specified
        if let platform = platform {
            let platformFilter = platform.lowercased()
            // The API expects specific platform values
            let _: Platform = switch platformFilter {
            case "ios": .ios
            case "macos": .macOs
            case "visionos": .visionOs
            default: throw AppStoreConnectError.invalidPlatform(platform: platform)
            }
            
            // Apply filter - this would need the actual API filter syntax
            // For now, we'll fetch all and filter locally
        }
        
        // Execute request
        let response = try await provider.request(request)
        
        // Map to our domain model
        return response.data.map { app in
            AppInfo(
                id: app.id,
                bundleId: app.attributes?.bundleID ?? "",
                name: app.attributes?.name ?? "",
                sku: app.attributes?.sku ?? "",
                primaryLocale: app.attributes?.primaryLocale ?? "en-US"
            )
        }
    }
    
    // MARK: - Download Metadata
    public func downloadMetadata(
        bundleId: String,
        platform: String,
        outputDirectory: String
    ) async throws {
        let provider = try await authService.getAPIProvider()
        
        // First, find the app
        let apps = try await listApps()
        guard let app = apps.first(where: { $0.bundleId == bundleId }) else {
            throw AppStoreConnectError.appNotFound(bundleId: bundleId)
        }
        
        // Create output directory
        let fileManager = FileManager.default
        let outputURL = URL(fileURLWithPath: outputDirectory)
        try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)
        
        // Get app info with all includes
        let appInfoRequest = APIEndpoint.v1.apps.id(app.id).get()
        CLIOutput.info("Fetching app info for app ID: \(app.id)")
        let appResponse = try await provider.request(appInfoRequest)
        
        // Save app-level metadata (categories, copyright, etc.)
        try await saveAppLevelMetadata(app: appResponse.data, outputDirectory: outputURL)
        
        // Track counts for reporting
        var appInfoLocalizationCount = 0
        
        // Get app infos directly - don't rely on included data
        let appInfosRequest = APIEndpoint.v1.apps.id(app.id).appInfos.get()
        let appInfosResponse = try await provider.request(appInfosRequest)
        
        if !appInfosResponse.data.isEmpty {
            // Get primary app info
            if let primaryAppInfo = appInfosResponse.data.first {
                // Get app info localizations
                let appInfoLocalizationsRequest = APIEndpoint
                    .v1.appInfos
                    .id(primaryAppInfo.id)
                    .appInfoLocalizations
                    .get()
                
                let appInfoLocalizationsResponse = try await provider.request(
                    appInfoLocalizationsRequest
                )
                appInfoLocalizationCount = appInfoLocalizationsResponse.data.count
                
                // Save app info localizations (name, subtitle, privacy policy)
                for localization in appInfoLocalizationsResponse.data {
                    try await saveAppInfoLocalization(
                        localization,
                        outputDirectory: outputURL
                    )
                }
            }
        }
        
        // Get localizations for the latest version
        if let latestVersion = appResponse.included?.compactMap({ item -> AppStoreVersion? in
            if case .appStoreVersion(let version) = item {
                return version
            }
            return nil
        }).first {
            // Get version localizations
            let localizationsRequest = APIEndpoint
                .v1.appStoreVersions
                .id(latestVersion.id)
                .appStoreVersionLocalizations
                .get()
            
            let localizationsResponse = try await provider.request(localizationsRequest)
            
            // Save each localization
            for localization in localizationsResponse.data {
                try await saveLocalization(
                    localization,
                    app: app,
                    outputDirectory: outputURL
                )
            }
            
            // Save version-level metadata
            try await saveVersionMetadata(version: latestVersion, outputDirectory: outputURL)
            
            CLIOutput.success("Downloaded metadata for \(bundleId) to \(outputDirectory)")
            CLIOutput.info("Found \(localizationsResponse.data.count) version localizations")
            if appInfoLocalizationCount > 0 {
                CLIOutput.info("Found \(appInfoLocalizationCount) app info localizations")
            }
        } else {
            // Try to fetch app store versions directly
            let versionsRequest = APIEndpoint.v1.apps.id(app.id).appStoreVersions.get()
            CLIOutput.info("Fetching app store versions for app ID: \(app.id)")
            let versionsResponse = try await provider.request(versionsRequest)
            
            CLIOutput.info("Found \(versionsResponse.data.count) app store version(s)")
            
            if let firstVersion = versionsResponse.data.first {
                // Get version localizations
                let localizationsRequest = APIEndpoint
                    .v1.appStoreVersions
                    .id(firstVersion.id)
                    .appStoreVersionLocalizations
                    .get()
                
                let localizationsResponse = try await provider.request(localizationsRequest)
                
                // Save each localization
                for localization in localizationsResponse.data {
                    try await saveLocalization(
                        localization,
                        app: app,
                        outputDirectory: outputURL
                    )
                }
                
                // Save version-level metadata
                try await saveVersionMetadata(version: firstVersion, outputDirectory: outputURL)
                
                CLIOutput.success("Downloaded metadata for \(bundleId) to \(outputDirectory)")
                CLIOutput.info("Found \(localizationsResponse.data.count) version localizations")
                if appInfoLocalizationCount > 0 {
                    CLIOutput.info("Found \(appInfoLocalizationCount) app info localizations")
                }
            } else {
                CLIOutput.warning("No app store version found for \(bundleId)")
                if appInfoLocalizationCount > 0 {
                    CLIOutput.info(
                        "Downloaded \(appInfoLocalizationCount) " +
                        "app info localizations to \(outputDirectory)"
                    )
                }
            }
        }
    }
    
    // MARK: - Upload Metadata
    public func uploadMetadata(
        bundleId: String,
        platform: String,
        inputDirectory: String,
        skipValidation: Bool
    ) async throws {
        let provider = try await authService.getAPIProvider()
        
        // First, find the app
        let apps = try await listApps()
        guard let app = apps.first(where: { $0.bundleId == bundleId }) else {
            throw AppStoreConnectError.appNotFound(bundleId: bundleId)
        }
        
        // Read metadata from directory
        let fileManager = FileManager.default
        let inputURL = URL(fileURLWithPath: inputDirectory)
        
        guard fileManager.fileExists(atPath: inputURL.path) else {
            throw AppStoreConnectError.fileNotFound(path: inputDirectory)
        }
        
        // Find all locale directories
        let contents = try fileManager.contentsOfDirectory(
            at: inputURL,
            includingPropertiesForKeys: nil
        )
        
        let localeDirs = contents.filter { url in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) 
                && isDirectory.boolValue
        }
        
        if localeDirs.isEmpty {
            throw AppStoreConnectError.metadataUploadFailed(
                reason: "No locale directories found in \(inputDirectory)"
            )
        }
        
        // Get the latest version for the specified platform
        let sdkPlatform = try mapPlatform(platform)
        let filterPlatform = [APIEndpoint.V1.Apps.WithID.AppStoreVersions.GetParameters
            .FilterPlatform(rawValue: sdkPlatform.rawValue)].compactMap { $0 }
        
        let versionsRequest = APIEndpoint.v1.apps.id(app.id).appStoreVersions.get(
            parameters: .init(
                filterPlatform: filterPlatform,
                limit: 200
            )
        )
        let versionsResponse = try await provider.request(versionsRequest)
        
        // Find the editable version or the one in preparation
        let editableVersion = versionsResponse.data.first { version in
            if let state = version.attributes?.appStoreState {
                return state == .prepareForSubmission || 
                       state == .developerRemovedFromSale ||
                       state == .waitingForReview ||
                       state == .inReview ||
                       state == .pendingDeveloperRelease
            }
            return false
        }
        
        guard let latestVersion = editableVersion ?? versionsResponse.data.first else {
            throw AppStoreConnectError.metadataUploadFailed(
                reason: "No editable app store version found for \(bundleId) on \(platform)"
            )
        }
        
        // Log which version we're uploading to
        let versionString = latestVersion.attributes?.versionString ?? "unknown"
        let versionState = latestVersion.attributes?.appStoreState?.rawValue ?? "unknown state"
        CLIOutput.info("Uploading metadata to version \(versionString) (\(versionState))")
        
        // Upload each locale
        var uploadedCount = 0
        for localeDir in localeDirs {
            let locale = localeDir.lastPathComponent
            
            do {
                try await uploadLocalization(
                    from: localeDir,
                    locale: locale,
                    versionId: latestVersion.id,
                    provider: provider,
                    skipValidation: skipValidation
                )
                uploadedCount += 1
                CLIOutput.success("Uploaded \(locale)")
            } catch {
                CLIOutput.error("Failed to upload \(locale): \(error.localizedDescription)")
            }
        }
        
        CLIOutput.success("Uploaded \(uploadedCount) localizations for \(bundleId)")
    }
    
    // MARK: - Private Helpers
    
    private func mapPlatform(_ platform: String) throws -> Platform {
        switch platform.lowercased() {
        case "ios":
            return .ios
        case "macos":
            return .macOs
        case "visionos":
            return .visionOs
        default:
            throw AppStoreConnectError.invalidPlatform(platform: platform)
        }
    }
    
    private func saveAppLevelMetadata(
        app: App,
        outputDirectory: URL
    ) async throws {
        // Save copyright
        if let contentRightsDeclaration = app.attributes?.contentRightsDeclaration {
            let file = outputDirectory.appendingPathComponent("copyright.txt")
            try contentRightsDeclaration.rawValue.write(to: file, atomically: true, encoding: .utf8)
        }
        
        // Note: Categories would need to be fetched from app categories relationship
        // For now, we'll skip them or fetch them separately
    }
    
    private func saveAppInfoLocalization(
        _ localization: AppInfoLocalization,
        outputDirectory: URL
    ) async throws {
        guard let locale = localization.attributes?.locale else { return }
        
        // Create locale directory
        let localeDir = outputDirectory.appendingPathComponent(locale)
        try FileManager.default.createDirectory(
            at: localeDir,
            withIntermediateDirectories: true
        )
        
        let attributes = localization.attributes
        
        // Name
        if let name = attributes?.name {
            let file = localeDir.appendingPathComponent("name.txt")
            try name.write(to: file, atomically: true, encoding: .utf8)
        }
        
        // Subtitle
        if let subtitle = attributes?.subtitle {
            let file = localeDir.appendingPathComponent("subtitle.txt")
            try subtitle.write(to: file, atomically: true, encoding: .utf8)
        }
        
        // Privacy Policy URL
        if let privacyPolicyURL = attributes?.privacyPolicyURL {
            let file = localeDir.appendingPathComponent("privacy_url.txt")
            try privacyPolicyURL.write(to: file, atomically: true, encoding: .utf8)
        }
        
        // Privacy Policy Text (for Apple TV)
        if let privacyPolicyText = attributes?.privacyPolicyText {
            let file = localeDir.appendingPathComponent("apple_tv_privacy_policy.txt")
            try privacyPolicyText.write(to: file, atomically: true, encoding: .utf8)
        }
    }
    
    private func saveVersionMetadata(
        version: AppStoreVersion,
        outputDirectory: URL
    ) async throws {
        // Save version string if needed
        if let versionString = version.attributes?.versionString {
            let file = outputDirectory.appendingPathComponent("app_version.txt")
            try versionString.write(to: file, atomically: true, encoding: .utf8)
        }
        
        // Save copyright from version if different
        if let copyright = version.attributes?.copyright {
            let file = outputDirectory.appendingPathComponent("copyright.txt")
            try copyright.write(to: file, atomically: true, encoding: .utf8)
        }
    }
    
    private func saveLocalization(
        _ localization: AppStoreVersionLocalization,
        app: AppInfo,
        outputDirectory: URL
    ) async throws {
        guard let locale = localization.attributes?.locale else { return }
        
        // Create locale directory
        let localeDir = outputDirectory.appendingPathComponent(locale)
        try FileManager.default.createDirectory(
            at: localeDir,
            withIntermediateDirectories: true
        )
        
        // Save each field as a separate text file (fastlane format)
        let attributes = localization.attributes
        
        // Description
        if let description = attributes?.description {
            let file = localeDir.appendingPathComponent("description.txt")
            try description.write(to: file, atomically: true, encoding: .utf8)
        }
        
        // Keywords
        if let keywords = attributes?.keywords {
            let file = localeDir.appendingPathComponent("keywords.txt")
            try keywords.write(to: file, atomically: true, encoding: .utf8)
        }
        
        // What's new (release notes)
        if let whatsNew = attributes?.whatsNew {
            let file = localeDir.appendingPathComponent("release_notes.txt")
            try whatsNew.write(to: file, atomically: true, encoding: .utf8)
        }
        
        // Promotional text
        if let promotionalText = attributes?.promotionalText {
            let file = localeDir.appendingPathComponent("promotional_text.txt")
            try promotionalText.write(to: file, atomically: true, encoding: .utf8)
        }
        
        // Marketing URL
        if let marketingURL = attributes?.marketingURL {
            let file = localeDir.appendingPathComponent("marketing_url.txt")
            try marketingURL.absoluteString.write(to: file, atomically: true, encoding: .utf8)
        }
        
        // Support URL
        if let supportURL = attributes?.supportURL {
            let file = localeDir.appendingPathComponent("support_url.txt")
            try supportURL.absoluteString.write(to: file, atomically: true, encoding: .utf8)
        }
    }
    
    private func uploadLocalization(
        from directory: URL,
        locale: String,
        versionId: String,
        provider: APIProvider,
        skipValidation: Bool
    ) async throws {
        _ = FileManager.default
        
        // Read metadata from individual text files (fastlane format)
        let metadata = LocalizationMetadata(
            description: try? String(
                contentsOf: directory.appendingPathComponent("description.txt"),
                encoding: .utf8
            ),
            keywords: try? String(
                contentsOf: directory.appendingPathComponent("keywords.txt"),
                encoding: .utf8
            ),
            marketingUrl: try? String(
                contentsOf: directory.appendingPathComponent("marketing_url.txt"),
                encoding: .utf8
            ),
            promotionalText: try? String(
                contentsOf: directory.appendingPathComponent("promotional_text.txt"),
                encoding: .utf8
            ),
            supportUrl: try? String(
                contentsOf: directory.appendingPathComponent("support_url.txt"),
                encoding: .utf8
            ),
            whatsNew: try? String(
                contentsOf: directory.appendingPathComponent("release_notes.txt"),
                encoding: .utf8
            )
        )
        
        if !skipValidation {
            try metadata.validate()
        }
        
        // Check if localization exists
        let localizationsRequest = APIEndpoint
            .v1.appStoreVersions
            .id(versionId)
            .appStoreVersionLocalizations
            .get(parameters: .init(
                filterLocale: [locale]
            ))
        
        let existingLocalizations = try await provider.request(localizationsRequest)
        
        let existing = existingLocalizations.data.first { 
            $0.attributes?.locale == locale 
        }
        
        if let existing = existing {
            // Update existing
            CLIOutput.info("Updating existing localization for \(locale)")
            if let promo = metadata.promotionalText {
                CLIOutput.info("  Promotional text: \(promo.prefix(50))...")
            }
            if let desc = metadata.description {
                CLIOutput.info("  Description: \(desc.prefix(50))...")
            }
            if let whatsNew = metadata.whatsNew {
                CLIOutput.info("  What's new: \(whatsNew.prefix(50))...")
            }
            
            let updateAttributes = AppStoreVersionLocalizationUpdateRequest.Data.Attributes(
                description: metadata.description,
                keywords: metadata.keywords,
                marketingURL: metadata.marketingUrl.flatMap { URL(string: $0) },
                promotionalText: metadata.promotionalText,
                supportURL: metadata.supportUrl.flatMap { URL(string: $0) },
                whatsNew: metadata.whatsNew
            )
            
            let updateData = AppStoreVersionLocalizationUpdateRequest.Data(
                type: .appStoreVersionLocalizations,
                id: existing.id,
                attributes: updateAttributes
            )
            
            let updateRequest = APIEndpoint
                .v1.appStoreVersionLocalizations
                .id(existing.id)
                .patch(AppStoreVersionLocalizationUpdateRequest(data: updateData))
            
            _ = try await provider.request(updateRequest)
        } else {
            // Create new
            CLIOutput.info("Creating new localization for \(locale)")
            if let promo = metadata.promotionalText {
                CLIOutput.info("  Promotional text: \(promo.prefix(50))...")
            }
            if let desc = metadata.description {
                CLIOutput.info("  Description: \(desc.prefix(50))...")
            }
            if let whatsNew = metadata.whatsNew {
                CLIOutput.info("  What's new: \(whatsNew.prefix(50))...")
            }
            
            let createAttributes = AppStoreVersionLocalizationCreateRequest.Data.Attributes(
                description: metadata.description,
                locale: locale,
                keywords: metadata.keywords,
                marketingURL: metadata.marketingUrl.flatMap { URL(string: $0) },
                promotionalText: metadata.promotionalText,
                supportURL: metadata.supportUrl.flatMap { URL(string: $0) },
                whatsNew: metadata.whatsNew
            )
            
            let versionData = AppStoreVersionLocalizationCreateRequest.Data
                .Relationships.AppStoreVersion.Data(
                    type: .appStoreVersions,
                    id: versionId
                )
            
            let versionRelationship = AppStoreVersionLocalizationCreateRequest.Data
                .Relationships.AppStoreVersion(data: versionData)
            
            let createData = AppStoreVersionLocalizationCreateRequest.Data(
                type: .appStoreVersionLocalizations,
                attributes: createAttributes,
                relationships: AppStoreVersionLocalizationCreateRequest.Data.Relationships(
                    appStoreVersion: versionRelationship
                )
            )
            
            let createRequest = APIEndpoint
                .v1.appStoreVersionLocalizations
                .post(AppStoreVersionLocalizationCreateRequest(data: createData))
            
            _ = try await provider.request(createRequest)
        }
    }
}

// MARK: - Domain Models

public struct AppInfo: Sendable {
    public let id: String
    public let bundleId: String
    public let name: String
    public let sku: String
    public let primaryLocale: String
}

struct LocalizationMetadata: Codable, Sendable {
    let description: String?
    let keywords: String?
    let marketingUrl: String?
    let promotionalText: String?
    let supportUrl: String?
    let whatsNew: String?
    
    func validate() throws {
        // Validate description length
        if let description = description, description.count > 4000 {
            throw AppStoreConnectError.invalidMetadataFormat(
                details: "Description exceeds 4000 characters"
            )
        }
        
        // Validate keywords
        if let keywords = keywords, keywords.count > 100 {
            throw AppStoreConnectError.invalidMetadataFormat(
                details: "Keywords exceed 100 characters"
            )
        }
        
        // Validate promotional text
        if let promotionalText = promotionalText, promotionalText.count > 170 {
            throw AppStoreConnectError.invalidMetadataFormat(
                details: "Promotional text exceeds 170 characters"
            )
        }
        
        // Validate what's new
        if let whatsNew = whatsNew, whatsNew.count > 4000 {
            throw AppStoreConnectError.invalidMetadataFormat(
                details: "What's new exceeds 4000 characters"
            )
        }
    }
}
