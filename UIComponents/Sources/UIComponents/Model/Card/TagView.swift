import Database
import SwiftUI

/// A view that displays a tag with a rounded rectangle background
internal struct TagView: View {
    @Bindable var tag: Tag

    var body: some View {
        Text(tag.name)
            .font(.caption2)
            .foregroundColor(Color.textSecondary)
            .padding(DesignConstants.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.Radius.small)
                    .fill(Color.backgroundSecondary)
            )
    }
}
