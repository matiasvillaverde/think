import SwiftUI

extension View {
    func listSectionSpacingIfAvailable(_ spacing: CGFloat = 8) -> some View {
        #if os(iOS)
            if #available(iOS 17.0, *) {
                return listSectionSpacing(spacing)
            } else {
                return self
            }
        #else
            return self
        #endif
    }
}
