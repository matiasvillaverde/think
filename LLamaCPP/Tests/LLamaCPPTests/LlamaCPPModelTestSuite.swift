import Abstractions
import Foundation
import llama
@testable import LLamaCPP
import Testing

/// Main test suite for all LlamaCPP tests that require model loading.
/// All tests are in a single suite marked as serialized to prevent concurrent model loading.
/// Tests are organized across multiple files using extensions for better organization.
@MainActor
@Suite("LlamaCPP Model Tests", .serialized)
internal struct LlamaCPPModelTestSuite {
    // This is the main suite struct. All model tests are added via extensions
    // in separate files for organization, but they all belong to this single suite.
}
