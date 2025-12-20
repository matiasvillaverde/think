import Foundation
@preconcurrency import AppStoreConnect_Swift_SDK

// MARK: - Sendable conformances for App Store Connect SDK models

extension CustomerReview: @retroactive @unchecked Sendable {}
extension AppStoreVersion: @retroactive @unchecked Sendable {}
