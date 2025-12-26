import Abstractions
import Foundation
import OSLog
import RemoteSession

/// State for a provider's API key configuration.
public struct ProviderKeyState: Identifiable, Sendable {
    /// The provider type
    public let provider: RemoteProviderType

    /// Whether an API key is configured for this provider
    public var isConfigured: Bool

    /// Whether validation is in progress
    public var isValidating: Bool

    /// The unique identifier for this state
    public var id: String { provider.rawValue }

    /// Creates a new provider key state.
    public init(provider: RemoteProviderType, isConfigured: Bool = false, isValidating: Bool = false) {
        self.provider = provider
        self.isConfigured = isConfigured
        self.isValidating = isValidating
    }
}

/// Protocol for the API key settings view model.
public protocol APIKeySettingsViewModeling: Actor {
    /// The current state of all providers.
    var providers: [ProviderKeyState] { get async }

    /// Loads the current configuration state from keychain.
    func loadConfiguration() async

    /// Sets an API key for a provider.
    ///
    /// - Parameters:
    ///   - key: The API key to store
    ///   - provider: The provider to store the key for
    func setAPIKey(_ key: String, for provider: RemoteProviderType) async throws

    /// Removes the API key for a provider.
    ///
    /// - Parameter provider: The provider to remove the key for
    func removeAPIKey(for provider: RemoteProviderType) async throws

    /// Checks if a provider has an API key configured.
    ///
    /// - Parameter provider: The provider to check
    /// - Returns: True if the provider has an API key configured
    func hasAPIKey(for provider: RemoteProviderType) async -> Bool
}

/// View model for managing API key settings.
///
/// This actor provides a thread-safe interface for managing
/// API keys for remote LLM providers.
public actor APIKeySettingsViewModel: APIKeySettingsViewModeling {
    // MARK: - Properties

    /// Logger for diagnostic information
    private let logger: Logger = Logger(
        subsystem: "ViewModels",
        category: String(describing: APIKeySettingsViewModel.self)
    )

    /// The API key manager for secure storage
    private let apiKeyManager: APIKeyManaging

    /// Internal state for all providers
    private var internalProviders: [ProviderKeyState] = []

    /// The current state of all providers
    public var providers: [ProviderKeyState] {
        internalProviders
    }

    // MARK: - Initialization

    /// Creates a new API key settings view model.
    ///
    /// - Parameter apiKeyManager: The API key manager for secure storage
    public init(apiKeyManager: APIKeyManaging = APIKeyManager.shared) {
        self.apiKeyManager = apiKeyManager

        // Initialize with all providers in unconfigured state
        internalProviders = RemoteProviderType.allCases.map { provider in
            ProviderKeyState(provider: provider)
        }
    }

    // MARK: - Public Methods

    /// Loads the current configuration state from keychain.
    public func loadConfiguration() async {
        logger.info("Loading API key configuration")

        var updatedProviders: [ProviderKeyState] = internalProviders

        for (index, provider) in RemoteProviderType.allCases.enumerated() {
            let hasKey: Bool = await apiKeyManager.hasKey(for: provider)
            updatedProviders[index] = ProviderKeyState(provider: provider, isConfigured: hasKey)

            if hasKey {
                logger.debug("Provider \(provider.rawValue) has API key configured")
            }
        }

        internalProviders = updatedProviders
        logger.info("Loaded configuration for \(updatedProviders.count) providers")
    }

    /// Sets an API key for a provider.
    public func setAPIKey(_ key: String, for provider: RemoteProviderType) async throws {
        logger.info("Setting API key for provider: \(provider.rawValue)")

        // Update state to show we're validating
        updateProviderValidating(provider: provider, isValidating: true)

        do {
            try await apiKeyManager.setKey(key, for: provider)

            // Update state to show key is configured
            updateProviderConfigured(provider: provider, isConfigured: true)
            updateProviderValidating(provider: provider, isValidating: false)
            logger.info("API key set successfully for provider: \(provider.rawValue)")
        } catch {
            // Reset validation state on error
            updateProviderValidating(provider: provider, isValidating: false)
            logger.error("Failed to set API key: \(error.localizedDescription)")
            throw error
        }
    }

    /// Removes the API key for a provider.
    public func removeAPIKey(for provider: RemoteProviderType) async throws {
        logger.info("Removing API key for provider: \(provider.rawValue)")

        do {
            try await apiKeyManager.deleteKey(for: provider)

            // Update state to show key is no longer configured
            updateProviderConfigured(provider: provider, isConfigured: false)
            updateProviderValidating(provider: provider, isValidating: false)
            logger.info("API key removed successfully for provider: \(provider.rawValue)")
        } catch {
            logger.error("Failed to remove API key: \(error.localizedDescription)")
            throw error
        }
    }

    /// Checks if a provider has an API key configured.
    public func hasAPIKey(for provider: RemoteProviderType) async -> Bool {
        await apiKeyManager.hasKey(for: provider)
    }

    // MARK: - Private Methods

    /// Updates the configured state for a specific provider.
    private func updateProviderConfigured(provider: RemoteProviderType, isConfigured: Bool) {
        guard let index = internalProviders.firstIndex(where: { $0.provider == provider }) else {
            return
        }

        let currentState: ProviderKeyState = internalProviders[index]
        internalProviders[index] = ProviderKeyState(
            provider: currentState.provider,
            isConfigured: isConfigured,
            isValidating: currentState.isValidating
        )
    }

    /// Updates the validating state for a specific provider.
    private func updateProviderValidating(provider: RemoteProviderType, isValidating: Bool) {
        guard let index = internalProviders.firstIndex(where: { $0.provider == provider }) else {
            return
        }

        let currentState: ProviderKeyState = internalProviders[index]
        internalProviders[index] = ProviderKeyState(
            provider: currentState.provider,
            isConfigured: currentState.isConfigured,
            isValidating: isValidating
        )
    }
}
