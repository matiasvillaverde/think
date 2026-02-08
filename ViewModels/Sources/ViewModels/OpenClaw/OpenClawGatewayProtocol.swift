// swiftlint:disable nesting
// swiftlint:disable redundant_string_enum_value

import Foundation

internal enum OpenClawGatewayProtocol {
    static let protocolVersion: Int = 3

    struct ConnectRequestFrame: Codable {
        let type: String
        let id: String
        let method: String
        let params: ConnectParams

        init(
            id: String,
            params: ConnectParams,
            type: String = "req",
            method: String = "connect"
        ) {
            self.type = type
            self.id = id
            self.method = method
            self.params = params
        }
    }

    struct ResponseFrame: Codable {
        let type: String
        let id: String
        let isOk: Bool
        let payload: HelloOkPayload?
        let error: ErrorPayload?

        enum CodingKeys: String, CodingKey {
            case type = "type"
            case id = "id"
            case isOk = "ok"
            case payload = "payload"
            case error = "error"
        }
    }

    struct ErrorPayload: Codable {
        let code: String?
        let message: String?
        let details: ErrorDetailsPayload?
    }

    struct ErrorDetailsPayload: Codable {
        let requestId: String?
    }

    struct EventFrame: Codable {
        let type: String
        let event: String
        let payload: ConnectChallengePayload?
    }

    struct ConnectChallengePayload: Codable {
        let nonce: String?
        let timestampMs: Int64?

        enum CodingKeys: String, CodingKey {
            case nonce = "nonce"
            case timestampMs = "ts"
        }
    }

    struct HelloOkPayload: Codable {
        let type: String
        let protocolVersion: Int?
        let auth: HelloOkAuthPayload?

        enum CodingKeys: String, CodingKey {
            case type = "type"
            case protocolVersion = "protocol"
            case auth = "auth"
        }
    }

    struct HelloOkAuthPayload: Codable {
        let deviceToken: String?
        let role: String?
        let scopes: [String]

        init(deviceToken: String?, role: String?, scopes: [String]) {
            self.deviceToken = deviceToken
            self.role = role
            self.scopes = scopes
        }

        init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(
                keyedBy: CodingKeys.self
            )
            self.deviceToken = try container.decodeIfPresent(String.self, forKey: .deviceToken)
            self.role = try container.decodeIfPresent(String.self, forKey: .role)
            self.scopes = try container.decodeIfPresent([String].self, forKey: .scopes) ?? []
        }

        private enum CodingKeys: String, CodingKey {
            case deviceToken = "deviceToken"
            case role = "role"
            case scopes = "scopes"
        }
    }

    struct ConnectParams: Codable {
        let minProtocol: Int
        let maxProtocol: Int
        let client: ClientInfo
        let caps: [String]
        let auth: AuthInfo?
        let role: String
        let scopes: [String]
        let device: DeviceInfo?

        init(
            minProtocol: Int,
            maxProtocol: Int,
            client: ClientInfo,
            auth: AuthInfo?,
            role: String,
            scopes: [String],
            device: DeviceInfo?,
            caps: [String] = []
        ) {
            self.minProtocol = minProtocol
            self.maxProtocol = maxProtocol
            self.client = client
            self.caps = caps
            self.auth = auth
            self.role = role
            self.scopes = scopes
            self.device = device
        }
    }

    struct ClientInfo: Codable {
        let id: String
        let displayName: String?
        let version: String
        let platform: String
        let mode: String
        let instanceId: String?
    }

    enum AuthInfo: Codable {
        case token(String)

        enum CodingKeys: String, CodingKey {
            case token = "token"
        }

        init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(
                keyedBy: CodingKeys.self
            )
            let value: String = try container.decode(String.self, forKey: .token)
            self = .token(value)
        }

        func encode(to encoder: Encoder) throws {
            var container: KeyedEncodingContainer<CodingKeys> = encoder.container(
                keyedBy: CodingKeys.self
            )
            switch self {
            case .token(let value):
                try container.encode(value, forKey: .token)
            }
        }
    }

    struct DeviceInfo: Codable {
        let id: String
        let publicKey: String
        let signature: String
        let signedAt: Int64
        let nonce: String?
    }

    enum HandshakeError: Error {
        case invalidResponse
        case pairingRequired(requestId: String)
        case serverRejected(message: String)
        case timeout
    }
}

// swiftlint:enable redundant_string_enum_value
// swiftlint:enable nesting
