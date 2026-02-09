import SwiftUI

extension ChannelMessageView: @preconcurrency Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.channel.id == rhs.channel.id &&
        lhs.channel.content == rhs.channel.content &&
        lhs.channel.isComplete == rhs.channel.isComplete &&
        lhs.channel.lastUpdated == rhs.channel.lastUpdated
    }
}
