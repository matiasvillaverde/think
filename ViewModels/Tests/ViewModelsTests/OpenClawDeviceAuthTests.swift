import CryptoKit
import Foundation
import Testing
@testable import ViewModels

@Suite("OpenClaw Device Auth Tests")
internal struct OpenClawDeviceAuthTests {
    @Test("DeviceId is sha256 hex of raw public key")
    func deviceIdMatchesSha256Hex() throws {
        let rawPrivate: Data = Data((0..<32).map { UInt8($0) })
        let privateKey: Curve25519.Signing.PrivateKey =
            try Curve25519.Signing.PrivateKey(rawRepresentation: rawPrivate)
        let identity: OpenClawDeviceIdentity = OpenClawDeviceIdentity(privateKey: privateKey)

        let publicRaw: Data = privateKey.publicKey.rawRepresentation
        let digest: SHA256.Digest = SHA256.hash(data: publicRaw)
        let expected: String = digest.compactMap { String(format: "%02x", $0) }.joined()

        #expect(identity.deviceId == expected)
        #expect(identity.publicKeyRawBase64Url == OpenClawBase64URL.encode(publicRaw))
    }

    @Test("Payload format matches upstream v2 when nonce is present")
    func payloadFormatV2() {
        let params: OpenClawDeviceAuth.PayloadParams = OpenClawDeviceAuth.PayloadParams(
            deviceId: "dev",
            clientId: "gateway_client",
            clientMode: "backend",
            role: "operator",
            scopes: ["operator.admin", "x"],
            signedAtMs: 1_700_000_000_123,
            token: "tkn",
            nonce: "nonce"
        )
        let payload: String = OpenClawDeviceAuth.buildPayload(params)
        #expect(
            payload
                == "v2|dev|gateway_client|backend|operator|operator.admin,x|1700000000123|tkn|nonce"
        )
    }

    @Test("Signature is base64url and verifies under public key")
    func signatureVerifies() throws {
        let rawPrivate: Data = Data((0..<32).map { UInt8(255 - $0) })
        let privateKey: Curve25519.Signing.PrivateKey =
            try Curve25519.Signing.PrivateKey(rawRepresentation: rawPrivate)
        let payload: String = "v2|dev|gateway_client|backend|operator|operator.admin|1|tkn|nonce"
        let signature: String = try OpenClawDeviceAuth.signPayload(
            privateKey: privateKey,
            payload: payload
        )

        guard let sigData: Data = OpenClawBase64URL.decode(signature) else {
            throw TestFailure("Signature did not base64url-decode")
        }

        let isValid: Bool = privateKey.publicKey.isValidSignature(sigData, for: Data(payload.utf8))
        #expect(isValid)
    }
}

private struct TestFailure: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}
