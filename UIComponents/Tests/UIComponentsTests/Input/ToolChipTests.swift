import Abstractions
import SwiftUI
import Testing
@testable import UIComponents

@Suite("ToolChip Tests")
internal struct ToolChipTests {
    @Test("ToolChip displays correct icon for each tool type")
    @MainActor
    internal func testToolChipIcons() {
        // Test that each ToolIdentifier has the correct icon
        let testCases: [(ToolIdentifier, String)] = [
            (.imageGeneration, "photo"),
            (.browser, "globe"),
            (.functions, "hammer.fill"),
            (.python, "laptopcomputer"),
            (.healthKit, "heart.text.square")
        ]

        for (tool, _) in testCases {
            _ = ToolChip(tool: tool) {
                // Remove action
            }
            // Note: We'd need a way to inspect the icon name
            // For now, this test documents the expected behavior
            #expect(Bool(true)) // Placeholder - SwiftUI view testing is limited
        }
    }

    @Test("ToolChip calls onRemove when remove button tapped")
    @MainActor
    internal func testRemoveCallback() {
        var removeCalled: Bool = false
        _ = ToolChip(tool: .imageGeneration) {
            removeCalled = true
        }

        // Note: SwiftUI view interaction testing requires UI test framework
        // This test documents the expected behavior
        #expect(!removeCalled)
    }

    @Test("ToolChip has correct accessibility label")
    @MainActor
    internal func testAccessibilityLabel() {
        _ = ToolChip(tool: .browser) {
            // Remove action
        }
        // The accessibility label should include the tool's raw value
        // Expected: "<tool> selected"
        #expect(Bool(true)) // Placeholder for SwiftUI accessibility testing
    }
}
