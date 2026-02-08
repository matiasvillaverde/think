import Foundation

internal enum OpenClawConnectTextBuilder {
    private typealias Proto = OpenClawGatewayProtocol

    internal static func makeConnectText(_ context: OpenClawConnectTextContext) throws -> String {
        let payloadParams: OpenClawDeviceAuth.PayloadParams = OpenClawDeviceAuth.PayloadParams(
            deviceId: context.identity.deviceId,
            clientId: OpenClawDeviceAuth.defaultClientId,
            clientMode: OpenClawDeviceAuth.defaultClientMode,
            role: context.attempt.role,
            scopes: context.attempt.scopes,
            signedAtMs: context.signedAtMs,
            token: context.attempt.authToken,
            nonce: context.nonce
        )
        let payload: String = OpenClawDeviceAuth.buildPayload(payloadParams)
        let signature: String = try OpenClawDeviceAuth.signPayload(
            privateKey: context.privateKey,
            payload: payload
        )

        let params: Proto.ConnectParams = Proto.ConnectParams(
            minProtocol: Proto.protocolVersion,
            maxProtocol: Proto.protocolVersion,
            client: Proto.ClientInfo(
                id: OpenClawDeviceAuth.defaultClientId,
                displayName: "Think",
                version: "dev",
                platform: context.platform,
                mode: OpenClawDeviceAuth.defaultClientMode,
                instanceId: nil
            ),
            auth: context.attempt.authToken.map { Proto.AuthInfo.token($0) },
            role: context.attempt.role,
            scopes: context.attempt.scopes,
            device: Proto.DeviceInfo(
                id: context.identity.deviceId,
                publicKey: context.identity.publicKeyRawBase64Url,
                signature: signature,
                signedAt: context.signedAtMs,
                nonce: context.nonce
            )
        )

        let frame: Proto.ConnectRequestFrame = Proto.ConnectRequestFrame(
            id: context.connectId,
            params: params
        )
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = []
        let data: Data = try encoder.encode(frame)
        return String(bytes: data, encoding: .utf8) ?? ""
    }
}
