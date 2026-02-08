import Foundation
import SwiftData

@Model
@DebugDescription
public final class AppSettings: Identifiable, Equatable {
    // MARK: - Identity

    @Attribute(.unique)
    public private(set) var id: UUID = UUID()

    @Attribute()
    public private(set) var createdAt: Date = Date()

    @Attribute()
    public internal(set) var updatedAt: Date = Date()

    // MARK: - Voice

    @Attribute()
    public internal(set) var talkModeEnabled: Bool

    @Attribute()
    public internal(set) var wakeWordEnabled: Bool

    @Attribute()
    public internal(set) var wakePhrase: String

    // MARK: - Node Mode

    @Attribute()
    public internal(set) var nodeModeEnabled: Bool

    @Attribute()
    public internal(set) var nodeModePort: Int

    @Attribute()
    public internal(set) var nodeModeAuthToken: String?

    // MARK: - OpenClaw Gateway

    /// User-configured remote OpenClaw gateway instances.
    @Relationship(deleteRule: .cascade)
    public internal(set) var openClawInstances: [OpenClawInstance] = []

    /// The active OpenClaw instance ID (if any).
    @Attribute()
    public internal(set) var activeOpenClawInstanceId: UUID?

    // MARK: - Initializer

    init(
        talkModeEnabled: Bool = false,
        wakeWordEnabled: Bool = true,
        wakePhrase: String = "hey think",
        nodeModeEnabled: Bool = false,
        nodeModePort: Int = 9876,
        nodeModeAuthToken: String? = nil,
        openClawInstances: [OpenClawInstance] = [],
        activeOpenClawInstanceId: UUID? = nil
    ) {
        self.talkModeEnabled = talkModeEnabled
        self.wakeWordEnabled = wakeWordEnabled
        self.wakePhrase = wakePhrase
        self.nodeModeEnabled = nodeModeEnabled
        self.nodeModePort = nodeModePort
        self.nodeModeAuthToken = nodeModeAuthToken
        self.openClawInstances = openClawInstances
        self.activeOpenClawInstanceId = activeOpenClawInstanceId
    }
}

#if DEBUG
extension AppSettings {
    @MainActor public static let preview: AppSettings = {
        AppSettings()
    }()
}
#endif
