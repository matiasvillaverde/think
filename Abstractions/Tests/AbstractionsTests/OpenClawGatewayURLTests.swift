import Abstractions
import Foundation
import Testing

@Suite("OpenClaw Gateway URL Tests")
struct OpenClawGatewayURLTests {
    @Test("Normalizes ws/wss URLs and enforces policy")
    func normalizesWebSocketURLs() throws {
        let secure: URL = try #require(
            OpenClawGatewayURL.normalize(
                "wss://example.com:18789",
                securityPolicy: .requireSecureExceptLocalhost
            )
        )
        #expect(secure.scheme == "wss")

        let localInsecure: URL = try #require(
            OpenClawGatewayURL.normalize(
                "ws://127.0.0.1:18789",
                securityPolicy: .requireSecureExceptLocalhost
            )
        )
        #expect(localInsecure.scheme == "ws")

        let remoteInsecure: URL? = OpenClawGatewayURL.normalize(
            "ws://example.com:18789",
            securityPolicy: .requireSecureExceptLocalhost
        )
        #expect(remoteInsecure == nil)
    }

    @Test("Rejects unsupported schemes and malformed URLs")
    func rejectsUnsupportedSchemes() {
        #expect(
            OpenClawGatewayURL.normalize(
                "ftp://example.com:18789",
                securityPolicy: .allowInsecure
            ) == nil
        )

        #expect(
            OpenClawGatewayURL.normalize(
                "wss://",
                securityPolicy: .allowInsecure
            ) == nil
        )

        #expect(
            OpenClawGatewayURL.normalize(
                "wss://exa mple.com:18789",
                securityPolicy: .allowInsecure
            ) == nil
        )
    }

    @Test("Trims whitespace and preserves path/query fragments")
    func trimsAndPreservesComponents() throws {
        let url: URL = try #require(
            OpenClawGatewayURL.normalize(
                "  https://example.com:18789/gateway?x=1#frag  ",
                securityPolicy: .allowInsecure
            )
        )
        #expect(url.scheme == "wss")
        #expect(url.host == "example.com")
        #expect(url.path == "/gateway")
        #expect(url.query == "x=1")
        #expect(url.fragment == "frag")
    }

    @Test("Localhost detection allows ws for loopback only")
    func localhostPolicy() throws {
        let localhost: URL = try #require(
            OpenClawGatewayURL.normalize(
                "ws://localhost:18789",
                securityPolicy: .requireSecureExceptLocalhost
            )
        )
        #expect(localhost.scheme == "ws")

        let loopbackV6: URL = try #require(
            OpenClawGatewayURL.normalize(
                "ws://[::1]:18789",
                securityPolicy: .requireSecureExceptLocalhost
            )
        )
        #expect(loopbackV6.scheme == "ws")

        let anyInterface: URL? = OpenClawGatewayURL.normalize(
            "ws://0.0.0.0:18789",
            securityPolicy: .requireSecureExceptLocalhost
        )
        #expect(anyInterface == nil)
    }

    @Test("Converts http/https to ws/wss")
    func convertsHttpSchemes() throws {
        let fromHttp: URL = try #require(
            OpenClawGatewayURL.normalize(
                "http://example.com:18789",
                securityPolicy: .allowInsecure
            )
        )
        #expect(fromHttp.scheme == "ws")

        let fromHttps: URL = try #require(
            OpenClawGatewayURL.normalize(
                "https://example.com:18789",
                securityPolicy: .allowInsecure
            )
        )
        #expect(fromHttps.scheme == "wss")
    }

    @Test("Defaults to wss when no scheme is provided")
    func defaultsToWss() throws {
        let url: URL = try #require(
            OpenClawGatewayURL.normalize(
                "example.com:18789",
                securityPolicy: .allowInsecure
            )
        )
        #expect(url.scheme == "wss")
        #expect(url.host == "example.com")
    }

    @Test("normalizeOrThrow throws structured errors")
    func normalizeOrThrowErrors() throws {
        #expect(throws: OpenClawGatewayURL.NormalizationError.invalidInput) {
            _ = try OpenClawGatewayURL.normalizeOrThrow("   ")
        }

        #expect(throws: OpenClawGatewayURL.NormalizationError.insecureTransportNotAllowed) {
            _ = try OpenClawGatewayURL.normalizeOrThrow(
                "ws://example.com:18789",
                securityPolicy: .requireSecureExceptLocalhost
            )
        }
    }
}
