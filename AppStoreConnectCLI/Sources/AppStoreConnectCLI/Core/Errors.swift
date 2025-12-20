import Foundation

/// Comprehensive error types for App Store Connect CLI operations
public enum AppStoreConnectError: Error, Equatable {
    // MARK: - Authentication Errors
    case authenticationFailed(reason: String)
    case invalidCredentials(details: String)
    case missingAPIKey(keyPath: String)
    case invalidAPIKey(reason: String)
    
    // MARK: - API Errors
    case apiRequestFailed(statusCode: Int, message: String)
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case networkError(underlying: Error)
    case invalidResponse(details: String)
    
    // MARK: - App Store Errors
    case appNotFound(bundleId: String)
    case versionAlreadyExists(version: String, platform: String)
    case versionNotFound(versionId: String)
    case buildNotFound(buildId: String)
    case invalidPlatform(platform: String)
    case invalidReleaseDate(date: String)
    case platformNotSupported(platform: String, bundleId: String)
    
    // MARK: - Metadata Errors
    case metadataDownloadFailed(reason: String)
    case metadataUploadFailed(reason: String)
    case invalidMetadataFormat(details: String)
    case missingRequiredMetadata(field: String)
    
    // MARK: - Configuration Errors
    case configurationError(message: String)
    case missingEnvironmentVariable(name: String)
    case invalidConfiguration(field: String, value: String)
    
    // MARK: - File System Errors
    case fileNotFound(path: String)
    case fileReadError(path: String, reason: String)
    case fileWriteError(path: String, reason: String)
    case directoryCreationFailed(path: String)
    
    // MARK: - CLI Errors
    case invalidCommand(command: String)
    case missingRequiredArgument(argument: String)
    case invalidArgument(argument: String, value: String)
    
    // MARK: - Equatable Implementation
    public static func == (lhs: AppStoreConnectError, rhs: AppStoreConnectError) -> Bool {
        switch (lhs, rhs) {
        case (.authenticationFailed(let lReason), .authenticationFailed(let rReason)):
            return lReason == rReason
        case (.invalidCredentials(let lDetails), .invalidCredentials(let rDetails)):
            return lDetails == rDetails
        case (.missingAPIKey(let lKeyPath), .missingAPIKey(let rKeyPath)):
            return lKeyPath == rKeyPath
        case (.invalidAPIKey(let lReason), .invalidAPIKey(let rReason)):
            return lReason == rReason
        case (.apiRequestFailed(let lCode, let lMessage), 
              .apiRequestFailed(let rCode, let rMessage)):
            return lCode == rCode && lMessage == rMessage
        case (.rateLimitExceeded(let lRetry), .rateLimitExceeded(let rRetry)):
            return lRetry == rRetry
        case (.invalidResponse(let lDetails), .invalidResponse(let rDetails)):
            return lDetails == rDetails
        case (.appNotFound(let lBundleId), .appNotFound(let rBundleId)):
            return lBundleId == rBundleId
        case (.versionAlreadyExists(let lVersion, let lPlatform), 
              .versionAlreadyExists(let rVersion, let rPlatform)):
            return lVersion == rVersion && lPlatform == rPlatform
        case (.versionNotFound(let lVersionId), .versionNotFound(let rVersionId)):
            return lVersionId == rVersionId
        case (.buildNotFound(let lBuildId), .buildNotFound(let rBuildId)):
            return lBuildId == rBuildId
        case (.invalidPlatform(let lPlatform), .invalidPlatform(let rPlatform)):
            return lPlatform == rPlatform
        case (.invalidReleaseDate(let lDate), .invalidReleaseDate(let rDate)):
            return lDate == rDate
        case (.platformNotSupported(let lPlatform, let lBundleId), 
              .platformNotSupported(let rPlatform, let rBundleId)):
            return lPlatform == rPlatform && lBundleId == rBundleId
        case (.metadataDownloadFailed(let lReason), .metadataDownloadFailed(let rReason)):
            return lReason == rReason
        case (.metadataUploadFailed(let lReason), .metadataUploadFailed(let rReason)):
            return lReason == rReason
        case (.invalidMetadataFormat(let lDetails), .invalidMetadataFormat(let rDetails)):
            return lDetails == rDetails
        case (.missingRequiredMetadata(let lField), .missingRequiredMetadata(let rField)):
            return lField == rField
        case (.configurationError(let lMessage), .configurationError(let rMessage)):
            return lMessage == rMessage
        case (.missingEnvironmentVariable(let lName), .missingEnvironmentVariable(let rName)):
            return lName == rName
        case (.invalidConfiguration(let lField, let lValue), 
              .invalidConfiguration(let rField, let rValue)):
            return lField == rField && lValue == rValue
        case (.fileNotFound(let lPath), .fileNotFound(let rPath)):
            return lPath == rPath
        case (.fileReadError(let lPath, let lReason), 
              .fileReadError(let rPath, let rReason)):
            return lPath == rPath && lReason == rReason
        case (.fileWriteError(let lPath, let lReason), 
              .fileWriteError(let rPath, let rReason)):
            return lPath == rPath && lReason == rReason
        case (.directoryCreationFailed(let lPath), .directoryCreationFailed(let rPath)):
            return lPath == rPath
        case (.invalidCommand(let lCommand), .invalidCommand(let rCommand)):
            return lCommand == rCommand
        case (.missingRequiredArgument(let lArgument), .missingRequiredArgument(let rArgument)):
            return lArgument == rArgument
        case (.invalidArgument(let lArgument, let lValue), 
              .invalidArgument(let rArgument, let rValue)):
            return lArgument == rArgument && lValue == rValue
        case (.networkError, .networkError):
            // Network errors are complex to compare, treat as equal if both are network errors
            return true
        default:
            return false
        }
    }
}

// MARK: - LocalizedError Implementation
extension AppStoreConnectError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        // Authentication Errors
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .invalidCredentials(let details):
            return "Invalid credentials: \(details)"
        case .missingAPIKey(let keyPath):
            return "API key not found at path: \(keyPath)"
        case .invalidAPIKey(let reason):
            return "Invalid API key: \(reason)"
            
        // API Errors
        case .apiRequestFailed(let statusCode, let message):
            return "API request failed with status \(statusCode): \(message)"
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limit exceeded. Retry after \(retryAfter) seconds"
            } else {
                return "Rate limit exceeded. Please retry later"
            }
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .invalidResponse(let details):
            return "Invalid API response: \(details)"
            
        // App Store Errors
        case .appNotFound(let bundleId):
            return "App not found with bundle ID: \(bundleId)"
        case .versionAlreadyExists(let version, let platform):
            return "Version \(version) already exists for platform \(platform)"
        case .versionNotFound(let versionId):
            return "Version not found with ID: \(versionId)"
        case .buildNotFound(let buildId):
            return "Build not found with ID: \(buildId)"
        case .invalidPlatform(let platform):
            return "Invalid platform: \(platform). Supported: iOS, macOS, visionOS"
        case .invalidReleaseDate(let date):
            return "Invalid release date format: \(date). Expected format: YYYY-MM-DD"
        case .platformNotSupported(let platform, let bundleId):
            return "Platform \(platform) is not supported for app \(bundleId)"
            
        // Metadata Errors
        case .metadataDownloadFailed(let reason):
            return "Metadata download failed: \(reason)"
        case .metadataUploadFailed(let reason):
            return "Metadata upload failed: \(reason)"
        case .invalidMetadataFormat(let details):
            return "Invalid metadata format: \(details)"
        case .missingRequiredMetadata(let field):
            return "Missing required metadata field: \(field)"
            
        // Configuration Errors
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .missingEnvironmentVariable(let name):
            return "Missing environment variable: \(name)"
        case .invalidConfiguration(let field, let value):
            return "Invalid configuration for \(field): \(value)"
            
        // File System Errors
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileReadError(let path, let reason):
            return "Failed to read file \(path): \(reason)"
        case .fileWriteError(let path, let reason):
            return "Failed to write file \(path): \(reason)"
        case .directoryCreationFailed(let path):
            return "Failed to create directory: \(path)"
            
        // CLI Errors
        case .invalidCommand(let command):
            return "Invalid command: \(command)"
        case .missingRequiredArgument(let argument):
            return "Missing required argument: \(argument)"
        case .invalidArgument(let argument, let value):
            return "Invalid value '\(value)' for argument \(argument)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .authenticationFailed, .invalidCredentials, .missingAPIKey, .invalidAPIKey:
            return "Check your API key configuration and ensure it's valid and properly formatted"
        case .apiRequestFailed(let statusCode, _):
            if statusCode == 401 {
                return "Verify your API credentials and permissions"
            } else if statusCode == 429 {
                return "Wait and retry your request after some time"
            } else {
                return "Check the API request parameters and try again"
            }
        case .rateLimitExceeded:
            return "Wait for the rate limit to reset before making additional requests"
        case .networkError:
            return "Check your internet connection and try again"
        case .appNotFound:
            return "Verify the bundle ID is correct and the app exists in App Store Connect"
        case .versionAlreadyExists:
            return "Use a different version number or update the existing version"
        case .invalidPlatform:
            return "Use one of the supported platforms: iOS, macOS, or visionOS"
        case .invalidReleaseDate:
            return "Provide the date in YYYY-MM-DD format (e.g., 2024-12-25)"
        case .platformNotSupported:
            return "The app may not be configured for this platform in App Store Connect"
        case .missingEnvironmentVariable(let name):
            return "Set the \(name) environment variable with the appropriate value"
        case .fileNotFound(let path):
            return "Ensure the file exists at \(path) or provide the correct path"
        case .configurationError, .invalidConfiguration:
            return "Check your configuration file and environment variables"
        default:
            return "Please check the documentation or contact support for assistance"
        }
    }
}

// MARK: - Result Type Extensions
public typealias AppStoreResult<T> = Result<T, AppStoreConnectError>

// MARK: - Result Type Convenience Methods
// Note: Extension methods removed due to ambiguity with Swift.Result
// Use Result.success(value) and Result.failure(error) directly
