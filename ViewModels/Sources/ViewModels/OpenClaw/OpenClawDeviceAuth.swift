import CryptoKit
import Foundation

// MARK: - Base64URL

internal enum OpenClawBase64URL {
    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decode(_ input: String) -> Data? {
        let normalized: String = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder: Int = normalized.count % 4
        let padded: String
        if remainder == 0 {
            padded = normalized
        } else {
            padded = normalized + String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: padded)
    }
}

// MARK: - Hex

internal enum OpenClawHex {
    static func lowercasedHexString(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Device Identity

internal struct OpenClawDeviceIdentity: Sendable, Equatable {
    let deviceId: String
    let publicKeyRawBase64Url: String
    let privateKeyRaw: Data

    init(privateKey: Curve25519.Signing.PrivateKey) {
        let publicRaw: Data = privateKey.publicKey.rawRepresentation
        self.deviceId = Self.fingerprintDeviceId(publicKeyRaw: publicRaw)
        self.publicKeyRawBase64Url = OpenClawBase64URL.encode(publicRaw)
        self.privateKeyRaw = privateKey.rawRepresentation
    }

    static func fingerprintDeviceId(publicKeyRaw: Data) -> String {
        let digest: SHA256.Digest = SHA256.hash(data: publicKeyRaw)
        return OpenClawHex.lowercasedHexString(Data(digest))
    }
}

// MARK: - Device Auth Payload

internal enum OpenClawDeviceAuth {
    // These defaults match OpenClaw's gateway client defaults.
    // See upstream: src/gateway/device-auth.ts and src/gateway/client.ts
    static let defaultRole: String = "operator"
    static let defaultScopes: [String] = ["operator.admin"]
    static let defaultClientId: String = "gateway-client"
    static let defaultClientMode: String = "backend"

    internal struct PayloadParams: Sendable, Equatable {
        let deviceId: String
        let clientId: String
        let clientMode: String
        let role: String
        let scopes: [String]
        let signedAtMs: Int64
        let token: String?
        let nonce: String?
    }

    static func buildPayload(_ params: PayloadParams) -> String {
        // Upstream chooses v2 when nonce is present, else v1.
        let version: String = (params.nonce == nil) ? "v1" : "v2"
        let scopesValue: String = params.scopes.joined(separator: ",")
        let tokenValue: String = params.token ?? ""

        var parts: [String] = [
            version,
            params.deviceId,
            params.clientId,
            params.clientMode,
            params.role,
            scopesValue,
            String(params.signedAtMs),
            tokenValue
        ]

        if version == "v2" {
            parts.append(params.nonce ?? "")
        }

        return parts.joined(separator: "|")
    }

    static func signPayload(
        privateKey: Curve25519.Signing.PrivateKey,
        payload: String
    ) throws -> String {
        let data: Data = Data(payload.utf8)
        let signature: Data = try privateKey.signature(for: data)
        return OpenClawBase64URL.encode(signature)
    }
}
