import Abstractions
import Foundation

/// Internal constants for the RAG module
/// This file provides RAG-specific constants while ensuring table name consistency with Abstractions
public enum Constants {
    // MARK: - Search and AI Configuration

    /// Default semantic search configuration
    public enum Search {
        /// Default similarity threshold for semantic search (lower = more similar required)
        public static var defaultThreshold: Double {
            Abstractions.Constants.defaultSearchThreshold
        }

        /// Default number of search results to return
        public static var defaultResultCount: Int {
            Abstractions.Constants.defaultSearchResultCount
        }

        /// Maximum number of search results for broad queries
        public static var maxResultCount: Int {
            Abstractions.Constants.maxSearchResultCount
        }

        /// Score assigned to direct database lookups (no similarity calculation)
        public static let directLookupScore: Double = 0.0

        /// Default embedding dimension for vector storage
        /// Delegates to Abstractions.Constants to maintain consistency
        public static var defaultEmbeddingDimension: Int {
            Abstractions.Constants.defaultEmbeddingDimension
        }
    }

    // MARK: - PDF Generation and Layout

    /// PDF document layout constants
    public enum PDF {
        /// Standard US Letter width in points (8.5 inches * 72 points/inch)
        public static let standardPageWidth: CGFloat = 612

        /// Standard US Letter height in points (11 inches * 72 points/inch)
        public static let standardPageHeight: CGFloat = 792

        /// Standard margin from page edge
        public static let standardMargin: CGFloat = 50

        /// Content area reduction for margins (2 * standardMargin)
        public static let marginOffset: CGFloat = 100

        /// Default font size for PDF text content
        public static let defaultFontSize: CGFloat = 18

        /// Error code for PDF creation failures
        public static let creationErrorCode: Int = 1
    }

    // MARK: - File Processing

    /// File processing configuration
    public enum FileProcessing {
        /// Default progress unit count for file operations
        public static let defaultProgressUnitCount: Int64 = 2

        /// Initial page index for single-page or text files
        public static let initialPageIndex: Int = 0

        /// Average token length for capacity estimation
        public static let averageTokenLength: Int = 5
    }

    // MARK: - Embedding Cache

    enum EmbeddingCache {
        static let defaultMaxEntries: Int = 512
    }

    // MARK: - Testing and Validation

    /// Constants used in tests and validation
    public enum Testing {
        /// Sleep duration for async operation coordination (0.5 seconds in nanoseconds)
        public static let concurrentTestSleepNanoseconds: UInt64 = 500_000_000

        /// Expected number of results after table deletion
        public static let expectedResultsAfterDeletion: Int = 2

        /// Expected total results across all tables
        public static let expectedTotalResults: Int = 3

        /// Default timeout multiplier for test operations
        public static let defaultTimeoutMultiplier: Int = 1
    }

    // MARK: - Geometric Calculations

    /// Common geometric values
    public enum Geometry {
        /// Origin point for coordinate systems
        public static let origin: CGFloat = 0

        /// Right angle in degrees
        public static let rightAngleDegrees: Double = 90.0

        /// Full circle in degrees
        public static let fullCircleDegrees: Double = 360.0
    }

    // MARK: - Backwards Compatibility (flat structure)

    /// Default progress unit count for file operations
    public static let defaultProgressUnitCount: Int64 = FileProcessing.defaultProgressUnitCount

    /// Initial page index for single-page or text files
    public static let initialPageIndex: Int = FileProcessing.initialPageIndex

    /// Average token length for capacity estimation
    public static let averageTokenLength: Int = FileProcessing.averageTokenLength

    // MARK: - Table Name Consistency
    // IMPORTANT: Use Abstractions.Constants for table name to ensure consistency

    /// Default table name for RAG operations
    /// Delegates to Abstractions.Constants.defaultTable to maintain consistency
    public static var defaultTable: String {
        Abstractions.Constants.defaultTable
    }

    /// Default embedding dimension from Abstractions
    /// Delegates to Abstractions.Constants to maintain consistency
    public static var embeddingDimension: Int {
        Abstractions.Constants.defaultEmbeddingDimension
    }
}
