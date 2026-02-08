import Foundation

/// Shared URL normalization and security policy for connecting to a remote OpenClaw gateway.
public enum OpenClawGatewayURL {
    public enum SecurityPolicy: Sendable, Equatable {
        /// Allow both `ws://` and `wss://`.
        case allowInsecure

        /// Require `wss://` except when connecting to localhost.
        case requireSecureExceptLocalhost
    }

    /// The default security policy.
    ///
    /// - Debug builds: allow insecure `ws://` for developer convenience.
    /// - Non-Debug builds: require `wss://` except for localhost.
    public static var defaultSecurityPolicy: SecurityPolicy {
#if DEBUG
        return .allowInsecure
#else
        return .requireSecureExceptLocalhost
#endif
    }

    /// Normalize a user-provided string into a WebSocket URL.
    ///
    /// Accepted inputs:
    /// - `ws://` / `wss://` (passed through)
    /// - `http://` / `https://` (converted to `ws://` / `wss://`)
    /// - hostnames without scheme (treated as `wss://{value}`)
    ///
    /// Returns `nil` if the input is invalid or violates the security policy.
    public static func normalize(
        _ raw: String,
        securityPolicy: SecurityPolicy = defaultSecurityPolicy
    ) -> URL? {
        let trimmed: String = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let url: URL? = {
            // If the user provided a scheme (contains "://"), treat it as an absolute URL.
            // Do not fall back to "wss://{value}" for unsupported schemes like "ftp://".
            if trimmed.contains("://") {
                return normalizeToWebSocketURL(trimmed)
            }
            return normalizeToWebSocketURL(trimmed) ?? URL(string: "wss://\(trimmed)")
        }()
        guard let url else {
            return nil
        }
        guard isValidWebSocketURL(url) else {
            return nil
        }

        guard isAllowedByPolicy(url, securityPolicy: securityPolicy) else {
            return nil
        }
        return url
    }

    public enum NormalizationError: Error, LocalizedError, Sendable, Equatable {
        case invalidInput
        case insecureTransportNotAllowed

        /// A user-facing description for URL normalization failures.
        public var errorDescription: String? {
            switch self {
            case .invalidInput:
                return "Invalid URL"
            case .insecureTransportNotAllowed:
                return "Insecure transport (ws://) is not allowed. Use wss:// instead."
            }
        }
    }

    /// Same as `normalize`, but throws a structured error instead of returning `nil`.
    public static func normalizeOrThrow(
        _ raw: String,
        securityPolicy: SecurityPolicy = defaultSecurityPolicy
    ) throws -> URL {
        let trimmed: String = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NormalizationError.invalidInput
        }

        let url: URL? = {
            if trimmed.contains("://") {
                return normalizeToWebSocketURL(trimmed)
            }
            return normalizeToWebSocketURL(trimmed) ?? URL(string: "wss://\(trimmed)")
        }()
        guard let url else {
            throw NormalizationError.invalidInput
        }
        guard isValidWebSocketURL(url) else {
            throw NormalizationError.invalidInput
        }

        guard isAllowedByPolicy(url, securityPolicy: securityPolicy) else {
            throw NormalizationError.insecureTransportNotAllowed
        }
        return url
    }

    // MARK: - Internals

    private static func normalizeToWebSocketURL(_ trimmed: String) -> URL? {
        guard let url: URL = URL(string: trimmed),
              let scheme: String = url.scheme?.lowercased() else {
            return nil
        }

        if scheme == "ws" || scheme == "wss" {
            return url
        }

        if scheme == "http" || scheme == "https" {
            var components: URLComponents? = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.scheme = (scheme == "https") ? "wss" : "ws"
            return components?.url
        }

        return nil
    }

    private static func isAllowedByPolicy(
        _ url: URL,
        securityPolicy: SecurityPolicy
    ) -> Bool {
        guard let scheme: String = url.scheme?.lowercased() else {
            return false
        }

        switch securityPolicy {
        case .allowInsecure:
            return scheme == "ws" || scheme == "wss"

        case .requireSecureExceptLocalhost:
            if scheme == "wss" {
                return true
            }
            if scheme == "ws" {
                return isLocalhost(url)
            }
            return false
        }
    }

    private static func isLocalhost(_ url: URL) -> Bool {
        guard let host: String = url.host?.lowercased() else {
            return false
        }
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    private static func isValidWebSocketURL(_ url: URL) -> Bool {
        guard let scheme: String = url.scheme?.lowercased(),
              scheme == "ws" || scheme == "wss" else {
            return false
        }
        guard let host: String = url.host, !host.isEmpty else {
            return false
        }
        return true
    }
}
