import SwiftUI

extension Image {
    enum SFSymbol: String {
        case exclamationmarkTriangle = "exclamationmark.triangle"
        case laurelLeading = "laurel.leading"
        case laurelTrailing = "laurel.trailing"
        case squareAndPencil = "square.and.pencil"
        case star = "star"
    }

    init(_ symbol: SFSymbol) {
        self.init(systemName: symbol.rawValue)
    }
}
