import Foundation

public extension Double {
    var kilobytes: UInt64 { UInt64(self * 1_024) }
    var megabytes: UInt64 { UInt64(self * 1_048_576) }
    var gigabytes: UInt64 { UInt64(self * 1_073_741_824) }
    var terabytes: UInt64 { UInt64(self * 1_099_511_627_776) }
}
