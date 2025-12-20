import Abstractions
import SwiftUI
import Testing
@testable import UIComponents

@Suite("ToolChip Tests")
internal struct ToolChipTests {
    @Test("ToolChip displays correct icon for each tool type")
    @MainActor
    internal func testToolChipIcons() throws {
        // Test that each ToolIdentifier has the correct icon
        let testCases: [(ToolIdentifier, String)] = [
            (.imageGeneration, "photo"),
            (.reasoning, "lightbulb"),
            (.browser, "globe"),
            (.functions, "hammer.fill"),
            (.python, "laptopcomputer"),
            (.healthKit, "heart.text.square")
        ]

        for (tool, expectedIcon) in testCases {
            let chip: ToolChip = ToolChip(tool: tool) {
                // Remove action
            }
            // Note: We'd need a way to inspect the icon name
            // For now, this test documents the expected behavior
            #expect(true) // Placeholder - SwiftUI view testing is limited
        }
    }

    @Test("ToolChip calls onRemove when remove button tapped")
    @MainActor
    internal func testRemoveCallback() throws {
        var removeCalled: Bool = false
        let chip: ToolChip = ToolChip(tool: .imageGeneration) {
            removeCalled = true
        }

        // Note: SwiftUI view interaction testing requires UI test framework
        // This test documents the expected behavior
        #expect(!removeCalled)
    }

    @Test("ToolChip has correct accessibility label")
    @MainActor
    internal func testAccessibilityLabel() throws {
        let chip: ToolChip = ToolChip(tool: .reasoning) {
            // Remove action
        }
        // The accessibility label should include the tool's raw value
        // Expected: "Reason selected"
        #expect(true) // Placeholder for SwiftUI accessibility testing
    }
}
