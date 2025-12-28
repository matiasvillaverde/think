import Foundation

/// Errors raised while validating signed plugin key bundles.
public enum PluginSigningKeyBundleError: Error, Equatable {
    case missingSignature
    case signatureExpired
    case signatureInvalid
    case signatureNotYetValid
    case signatureRevoked
    case unknownKey
}
