import Foundation

extension Duration {
    // MARK: - Constants

    private enum Constants {
        static let attosecondsPerSecond: Double = 1e18
    }

    var timeInterval: TimeInterval {
        TimeInterval(components.seconds) + Double(components.attoseconds) / Constants.attosecondsPerSecond
    }

    var abs: Duration {
        if self < Duration.zero {
            return self * -1
        }

        return self
    }
}
