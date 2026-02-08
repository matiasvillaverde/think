import Abstractions

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
                label: "OpenClaw: Off",
                level: .neutral
            )
        }

        switch status {
        case .idle:
            return OpenClawStatusStyle(
                symbolName: "antenna.radiowaves.left.and.right",
                label: "OpenClaw: Idle",
                level: .neutral
            )

        case .connecting:
            return OpenClawStatusStyle(
                symbolName: "antenna.radiowaves.left.and.right",
                label: "OpenClaw: Connecting",
                level: .warning
            )

        case .connected:
            return OpenClawStatusStyle(
                symbolName: "antenna.radiowaves.left.and.right",
                label: "OpenClaw: Connected",
                level: .success
            )

        case .pairingRequired:
            return OpenClawStatusStyle(
                symbolName: "exclamationmark.triangle.fill",
                label: "OpenClaw: Pairing Required",
                level: .warning
            )

        case .failed:
            return OpenClawStatusStyle(
                symbolName: "xmark.octagon.fill",
                label: "OpenClaw: Failed",
                level: .error
            )
        }
    }
}
