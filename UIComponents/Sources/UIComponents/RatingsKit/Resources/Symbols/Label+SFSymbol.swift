import SwiftUI

extension Label where Title == Text, Icon == Image {
    nonisolated init(
        _ titleKey: LocalizedStringKey,
        symbol: Image.SFSymbol
    ) {
        self.init(titleKey, systemImage: symbol.rawValue)
    }

    nonisolated init(
        _ titleKey: String,
        symbol: Image.SFSymbol
    ) {
        self.init(titleKey, systemImage: symbol.rawValue)
    }
}
