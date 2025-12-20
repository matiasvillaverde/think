import Abstractions
import Foundation

/// Constants used across the Tools module
public enum ToolConstants {
    /// Default number of search results
    public static let defaultSearchResultCount: Int = 3

    /// Maximum number of search results
    public static let maxSearchResultCount: Int = 5

    /// Default number of semantic search results
    public static let defaultSemanticSearchResults: Int = 5

    /// Default semantic search threshold
    public static let defaultSemanticSearchThreshold: Double = Abstractions.Constants.defaultSearchThreshold

    /// Maximum semantic search results
    public static let maxSemanticSearchResults: Int = 20

    /// Default health data limit
    public static let defaultHealthDataLimit: Int = 50

    /// Maximum health data limit
    public static let maxHealthDataLimit: Int = 100

    /// Seconds per day for date calculations
    public static let secondsPerDay: Double = 86_400

    /// Maximum number of items to display in health data results
    public static let maxDisplayHealthItems: Int = 5

    /// Byte Order Mark constants
    public enum BOM {
        /// UTF-8 Byte Order Mark bytes
        private static let utf8FirstByte: UInt8 = 0xEF
        private static let utf8SecondByte: UInt8 = 0xBB
        private static let utf8ThirdByte: UInt8 = 0xBF
        /// UTF-16 Big Endian first byte
        private static let utf16BEFirstByte: UInt8 = 0xFE
        /// UTF-16 Big Endian second byte  
        private static let utf16BESecondByte: UInt8 = 0xFF
        /// UTF-16 Little Endian first byte
        private static let utf16LEFirstByte: UInt8 = 0xFF
        /// UTF-16 Little Endian second byte
        private static let utf16LESecondByte: UInt8 = 0xFE

        /// UTF-8 Byte Order Mark
        public static let utf8: [UInt8] = [utf8FirstByte, utf8SecondByte, utf8ThirdByte]
        /// UTF-16 Big Endian Byte Order Mark
        public static let utf16BE: [UInt8] = [utf16BEFirstByte, utf16BESecondByte]
        /// UTF-16 Little Endian Byte Order Mark
        public static let utf16LE: [UInt8] = [utf16LEFirstByte, utf16LESecondByte]
    }
}
