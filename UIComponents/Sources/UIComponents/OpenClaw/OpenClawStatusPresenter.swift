import Abstractions
import Foundation

internal enum OpenClawStatusLevel: Sendable, Equatable {
    case error
    case neutral
    case success
    case warning
}

internal struct OpenClawStatusStyle: Sendable, Equatable {
    let symbolName: String
    let label: String
    let level: OpenClawStatusLevel
}

internal enum OpenClawStatusPresenter {
    static func style(
        hasActiveInstance: Bool,
        status: OpenClawConnectionStatus
    ) -> OpenClawStatusStyle {
        if !hasActiveInstance {
            return OpenClawStatusStyle(
                symbolName: "antenna.radiowaves.left.and.right.slash",
                label: String(localized: "OpenClaw: Off", bundle: .module),
                level: .neutral
            )
        }

        switch status {
        case .idle:
            return OpenClawStatusStyle(
                symbolName: "antenna.radiowaves.left.and.right",
                label: String(localized: "OpenClaw: Idle", bundle: .module),
                level: .neutral
            )

        case .connecting:
            return OpenClawStatusStyle(
                symbolName: "antenna.radiowaves.left.and.right",
                label: String(localized: "OpenClaw: Connecting", bundle: .module),
                level: .warning
            )

        case .connected:
            return OpenClawStatusStyle(
                symbolName: "antenna.radiowaves.left.and.right",
                label: String(localized: "OpenClaw: Connected", bundle: .module),
                level: .success
            )

        case .pairingRequired:
            return OpenClawStatusStyle(
                symbolName: "exclamationmark.triangle.fill",
                label: String(
                    localized: "OpenClaw: Pairing Required",
                    bundle: .module
                ),
                level: .warning
            )

        case .failed:
            return OpenClawStatusStyle(
                symbolName: "xmark.octagon.fill",
                label: String(localized: "OpenClaw: Failed", bundle: .module),
                level: .error
            )
        }
    }
}
