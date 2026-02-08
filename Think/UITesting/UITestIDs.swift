import Foundation

internal enum UITestConstants {
    static let secondMessageFinalChannelId = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
}

/// Hard-coded IDs so XCUITests can reliably query tool/channel views.
internal struct UITestIDs: Sendable {
    internal static let shared = UITestIDs()

    internal let analysisChannelId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    internal let commentaryChannelId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    internal let toolChannelId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    internal let toolChannelId2 = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
    internal let finalChannelId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    internal let scrollStreamingFinalChannelId = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
    internal let toolExecutionId = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    internal let toolExecutionId2 = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
}
