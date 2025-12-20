import Foundation
@preconcurrency import AppStoreConnect_Swift_SDK

/// Service for managing App Store Connect versions
public actor VersionService {
    private let authService: AppStoreConnectAuthenticationService
    
    public init(authService: AppStoreConnectAuthenticationService) {
        self.authService = authService
    }
    
    // MARK: - Version Management
    
    /// Creates a new version for the specified app and platform
    public func createVersion(
        bundleId: String,
        versionString: String,
        platform: String,
        isDraft: Bool = false
    ) async throws -> AppStoreVersion {
        let provider = try await authService.getAPIProvider()
        
        // First, find the app by bundle ID
        let app = try await findApp(bundleId: bundleId)
        
        // Map platform string to SDK Platform enum
        let sdkPlatform = try mapPlatform(platform)
        
        // Check if version already exists - if so, throw appropriate error
        if try await findExistingVersion(
            appId: app.id,
            versionString: versionString,
            platform: sdkPlatform
        ) != nil {
            throw AppStoreConnectError.versionAlreadyExists(
                version: versionString,
                platform: platform
            )
        }
        
        // Try to create the version
        let createRequest = AppStoreVersionCreateRequest(
            data: AppStoreVersionCreateRequest.Data(
                type: .appStoreVersions,
                attributes: AppStoreVersionCreateRequest.Data.Attributes(
                    platform: sdkPlatform,
                    versionString: versionString
                ),
                relationships: AppStoreVersionCreateRequest.Data.Relationships(
                    app: AppStoreVersionCreateRequest.Data.Relationships.App(
                        data: AppStoreVersionCreateRequest.Data.Relationships.App.Data(
                            type: .apps,
                            id: app.id
                        )
                    )
                )
            )
        )
        
        do {
            let response = try await provider.request(
                APIEndpoint.v1.appStoreVersions.post(createRequest)
            )
            return response.data
        } catch {
            // If creation failed with 409, check if version exists now or if platform unsupported
            if case APIProvider.Error.requestFailure(let statusCode, let errorResponse, _) = error,
               statusCode == 409 {
                // Try to find the version again in case it was created in the meantime
                if try await findExistingVersion(
                    appId: app.id,
                    versionString: versionString,
                    platform: sdkPlatform
                ) != nil {
                    throw AppStoreConnectError.versionAlreadyExists(
                        version: versionString,
                        platform: platform
                    )
                }
                
                // Check if the error indicates platform not supported
                let errorDetails = errorResponse?.errors?.first?.detail ?? ""
                if errorDetails.contains("ENTITY_ERROR.RELATIONSHIP.INVALID") ||
                   errorDetails.contains("cannot create a new version") ||
                   errorDetails.contains("invalid value") {
                    throw AppStoreConnectError.platformNotSupported(
                        platform: platform,
                        bundleId: bundleId
                    )
                }
            }
            // Re-throw the original error if it's not a version conflict
            throw error
        }
    }
    
    /// Lists versions for the specified app and platform
    public func listVersions(
        bundleId: String,
        platform: String? = nil
    ) async throws -> [AppStoreVersion] {
        let provider = try await authService.getAPIProvider()
        let app = try await findApp(bundleId: bundleId)
        
        var filterPlatform: 
            [APIEndpoint.V1.Apps.WithID.AppStoreVersions.GetParameters.FilterPlatform]?
        if let platform = platform {
            let sdkPlatform = try mapPlatform(platform)
            filterPlatform = [APIEndpoint.V1.Apps.WithID.AppStoreVersions.GetParameters
                .FilterPlatform(rawValue: sdkPlatform.rawValue)].compactMap { $0 }
        }
        
        let request = APIEndpoint.v1.apps.id(app.id).appStoreVersions.get(
            parameters: .init(
                filterPlatform: filterPlatform,
                limit: 200
            )
        )
        
        let response = try await provider.request(request)
        return response.data
    }
    
    /// Updates a version
    public func updateVersion(
        versionId: String,
        copyright: String? = nil,
        releaseDate: String? = nil
    ) async throws {
        let provider = try await authService.getAPIProvider()
        
        var attributes = AppStoreVersionUpdateRequest.Data.Attributes()
        
        if let copyright = copyright {
            attributes.copyright = copyright
        }
        
        if let releaseDate = releaseDate {
            // Parse date string and convert to Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: releaseDate) {
                attributes.earliestReleaseDate = date
            } else {
                throw AppStoreConnectError.invalidReleaseDate(date: releaseDate)
            }
        }
        
        let updateRequest = AppStoreVersionUpdateRequest(
            data: AppStoreVersionUpdateRequest.Data(
                type: .appStoreVersions,
                id: versionId,
                attributes: attributes
            )
        )
        
        let request = APIEndpoint.v1.appStoreVersions.id(versionId).patch(updateRequest)
        _ = try await provider.request(request)
    }
    
    /// Deletes a version
    public func deleteVersion(versionId: String) async throws {
        let provider = try await authService.getAPIProvider()
        let request = APIEndpoint.v1.appStoreVersions.id(versionId).delete
        try await provider.request(request)
    }
    
    // MARK: - Private Helpers
    
    private func findApp(bundleId: String) async throws -> App {
        let provider = try await authService.getAPIProvider()
        let appsRequest = APIEndpoint.v1.apps.get(
            parameters: .init(
                filterBundleID: [bundleId],
                limit: 1
            )
        )
        
        let appsResponse = try await provider.request(appsRequest)
        
        guard let app = appsResponse.data.first else {
            throw AppStoreConnectError.appNotFound(bundleId: bundleId)
        }
        
        return app
    }
    
    private func findExistingVersion(
        appId: String,
        versionString: String,
        platform: Platform
    ) async throws -> AppStoreVersion? {
        let provider = try await authService.getAPIProvider()
        let filterPlatform = [APIEndpoint.V1.Apps.WithID.AppStoreVersions.GetParameters
            .FilterPlatform(rawValue: platform.rawValue)].compactMap { $0 }
        let versionsRequest = APIEndpoint.v1.apps.id(appId).appStoreVersions.get(
            parameters: .init(
                filterPlatform: filterPlatform,
                filterVersionString: [versionString],
                limit: 1
            )
        )
        
        let versionsResponse = try await provider.request(versionsRequest)
        return versionsResponse.data.first
    }
    
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
}
