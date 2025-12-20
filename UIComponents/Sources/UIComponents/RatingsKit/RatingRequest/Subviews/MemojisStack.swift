import SwiftUI

internal enum MemojiAssets {
    static let person1: ImageResource = ImageResource(name: "Person1", bundle: .module)
    static let person2: ImageResource = ImageResource(name: "Person2", bundle: .module)
    static let person3: ImageResource = ImageResource(name: "Person3", bundle: .module)
    static let person4: ImageResource = ImageResource(name: "Person4", bundle: .module)
    static let person5: ImageResource = ImageResource(name: "Person5", bundle: .module)
    static let person6: ImageResource = ImageResource(name: "Person6", bundle: .module)
    static let person7: ImageResource = ImageResource(name: "Person7", bundle: .module)
    static let person8: ImageResource = ImageResource(name: "Person8", bundle: .module)
}

extension [Image] {
    /// A collection of default Memoji images.
    static let defaultMemojis: Self = [
        Image(MemojiAssets.person1),
        Image(MemojiAssets.person2),
        Image(MemojiAssets.person3),
        Image(MemojiAssets.person4),
        Image(MemojiAssets.person5),
        Image(MemojiAssets.person6),
        Image(MemojiAssets.person7),
        Image(MemojiAssets.person8)
    ]
}

internal struct MemojisStack: View {
    private enum Constants {
        static let itemSpacing: CGFloat = -10
        static let firstIndex: Int = 1
        static let secondIndex: Int = 2
        static let thirdIndex: Int = 3
        static let firstZIndex: Double = 3
        static let secondZIndex: Double = 2
        static let thirdZIndex: Double = 1
        static let memojiSize: CGFloat = 40
        static let strokeWidth: CGFloat = 4
    }

    let memojis: [Image]

    var body: some View {
        HStack(alignment: .center, spacing: Constants.itemSpacing) {
            memoji(at: Constants.firstIndex)
                .zIndex(Constants.firstZIndex)

            memoji(at: Constants.secondIndex)
                .zIndex(Constants.secondZIndex)

            memoji(at: Constants.thirdIndex)
                .zIndex(Constants.thirdZIndex)
        }
    }

    @ViewBuilder
    private func memoji(at index: Int) -> some View {
        if let memoji = memojis[safe: index] {
            memoji
                .resizable()
                .frame(width: Constants.memojiSize, height: Constants.memojiSize)
                .background(.background.secondary)
                .clipShape(.circle)
                .background(
                    Circle()
                        .stroke(.background, lineWidth: Constants.strokeWidth)
                )
        }
    }
}

#Preview {
    MemojisStack(memojis: .defaultMemojis)
        .padding()
}
