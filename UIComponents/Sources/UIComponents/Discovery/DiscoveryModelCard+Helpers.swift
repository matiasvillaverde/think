import Abstractions
import SwiftUI

// MARK: - Helper Methods

extension DiscoveryModelCard {
    func formatNumber(_ number: Int) -> String {
        if number >= Int(DiscoveryConstants.Numbers.million) {
            return String(format: "%.1fM", Double(number) / DiscoveryConstants.Numbers.million)
        }
        if number >= Int(DiscoveryConstants.Numbers.thousand) {
            return String(format: "%.1fK", Double(number) / DiscoveryConstants.Numbers.thousand)
        }
        return "\(number)"
    }

    var accessibilityLabel: String {
        let downloadCount: String = "\(formatNumber(model.downloads)) downloads"
        let likeCount: String = "\(formatNumber(model.likes)) likes"
        let stats: String = "\(downloadCount), \(likeCount)"
        let backend: String = model.primaryBackend?.displayName ?? "Unknown backend"
        let hasImage: Bool = !model.imageUrls.isEmpty || model.cardData?.thumbnail != nil
        let imageInfo: String = hasImage ?
            String(localized: "with image", bundle: .module) : ""

        let baseInfo: String = [
            model.name,
            "by \(model.author)",
            stats,
            model.formattedTotalSize,
            backend
        ].joined(separator: ", ")
        return imageInfo.isEmpty ? baseInfo : "\(baseInfo), \(imageInfo)"
    }
}
