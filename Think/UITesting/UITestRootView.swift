import Abstractions
import Database
import SwiftUI
import UIComponents

/// Deterministic, fast UI-test entry point.
///
/// Launch with `--ui-testing` to bypass onboarding and seed a scrollable chat with
/// streaming + tool + thinking content.
struct UITestRootView: View {
    @Environment(\.database) private var database: DatabaseProtocol

    @State private var didSeed: Bool = false
    @State private var seedError: String?

    var body: some View {
        Group {
            if let seedError {
                VStack(spacing: 12) {
                    Text("UI Test Seed Failed")
                        .font(.headline)
                    Text(seedError)
                        .font(.caption)
                        .textSelection(.enabled)
                }
                .padding()
            } else {
                UITestChatHostView()
            }
        }
        .task {
            guard !didSeed else { return }
            didSeed = true
            await seedIfNeeded()
        }
    }

    private func seedIfNeeded() async {
        do {
            try await UITestSeed.run(database: database)
        } catch {
            await MainActor.run {
                seedError = String(describing: error)
            }
        }
    }
}
