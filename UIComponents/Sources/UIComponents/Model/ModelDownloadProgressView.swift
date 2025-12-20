import Database
import SwiftUI

/// A view that displays download progress for a model
internal struct ModelDownloadProgressView: View {
    // **MARK: - Layout Constants**
    private enum Layout {
        static let progressHeight: CGFloat = 8
        static let cornerRadius: CGFloat = 4
        static let cornerRadiusLarge: CGFloat = 8
        static let spacing: CGFloat = 8
        static let progressPadding: CGFloat = 12
        static let progressPaddingLarge: CGFloat = 24
        static let seconds: Int = 60
    }

    // **MARK: - Properties**
    let model: Model

    // **MARK: - State**
    @State private var lastProgressUpdate: (progress: Double, date: Date)?
    @State private var downloadSpeed: Double?
    @State private var estimatedTimeRemaining: TimeInterval?

    @State private var recentSpeedMeasurements: [(speed: Double, timestamp: Date)] = []
    private let maxSpeedMeasurements: Int = 5 // Number of speed measurements to keep
    private let smoothingFactor: Double = 0.3 // Lower value = smoother changes (0.0-1.0)
    private let smoothingFactorLarge: Double = 0.15 // Lower value = smoother changes (0.0-1.0)

    // **MARK: - Body**
    var body: some View {
        VStack(spacing: Layout.spacing) {
            progressBarView
            statusView
        }
        .padding(.horizontal)
        .onAppear {
            startTrackingProgress()
        }
        .onChange(of: downloadProgress) { _, newProgress in
            updateEstimatedTimeRemaining(newProgress)
        }
    }

    // **MARK: - UI Components**

    /// Progress bar component
    private var progressBarView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .fill(Color.backgroundPrimary)
                    .frame(height: Layout.progressHeight)

                // Progress fill
                if let progress = downloadProgress {
                    RoundedRectangle(cornerRadius: Layout.cornerRadius)
                        .fill(Color.accentColor)
                        .frame(
                            width: max(
                                Layout.cornerRadiusLarge,
                                geometry.size.width * CGFloat(progress)
                            ),
                            height: Layout.progressHeight
                        )
                        .animation(.smooth, value: progress)
                }
            }
            .padding(.vertical, Layout.progressPadding)
        }
        .frame(height: Layout.progressHeight + (Layout.progressPaddingLarge))
    }

    /// Status text component
    private var statusView: some View {
        HStack {
            if let progress = downloadProgress {
                Text("\(Int(progress * 100))% Downloaded", bundle: .module)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                // Display estimated time remaining
                if
                    let timeRemaining = estimatedTimeRemaining,
                    timeRemaining.isFinite,
                    timeRemaining > 0 {
                    Text(timeRemainingText(from: timeRemaining))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Preparing download...", bundle: .module)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    // **MARK: - Helper Properties**

    /// Gets the download progress from the model
    private var downloadProgress: Double? {
        switch model.state {
        case .downloadingActive, .downloadingPaused:
            model.downloadProgress

        default:
            nil
        }
    }

    // **MARK: - Helper Methods**

    /// Start tracking progress to calculate download speed
    private func startTrackingProgress() {
        guard let progress = downloadProgress else {
            return
        }
        lastProgressUpdate = (progress, Date())
    }

    /// Update the estimated time remaining based on download speed
    private func updateEstimatedTimeRemaining(_ newProgress: Double?) {
        guard
            let newProgress,
            let lastUpdate = lastProgressUpdate
        else {
            return
        }

        let now: Date = Date()
        let timeElapsed: TimeInterval = now.timeIntervalSince(lastUpdate.date)

        // Calculate download speed (progress per second)
        guard timeElapsed > 0 else {
            return
        }

        let progressChange: Double = newProgress - lastUpdate.progress
        let instantSpeed: Double = progressChange / timeElapsed

        // Add current speed to measurements list
        recentSpeedMeasurements.append((speed: instantSpeed, timestamp: now))

        // Keep only the most recent measurements
        if recentSpeedMeasurements.count > maxSpeedMeasurements {
            recentSpeedMeasurements.removeFirst()
        }

        // Calculate weighted average speed (more recent = higher weight)
        var weightedSpeed: Double = 0
        var totalWeight: Double = 0

        for (index, measurement) in recentSpeedMeasurements.enumerated() {
            let weight: Double = Double(index + 1) // Higher weight for more recent measurements
            weightedSpeed += measurement.speed * weight
            totalWeight += weight
        }

        if totalWeight > 0 {
            let averageSpeed: Double = weightedSpeed / totalWeight

            // Update our tracked download speed with some smoothing
            if let currentSpeed = downloadSpeed {
                // Apply smoothing: newValue = (1-factor)*oldValue + factor*newMeasurement
                downloadSpeed = (1 - smoothingFactor)
                    * currentSpeed + smoothingFactor * averageSpeed
            } else {
                downloadSpeed = averageSpeed
            }
        }

        // Calculate estimated time remaining
        if let speed = downloadSpeed, speed > 0 {
            let remainingProgress: Double = 1.0 - newProgress
            let newEstimate: Double = remainingProgress / speed

            // Apply smoothing to the time estimate
            if let currentEstimate = estimatedTimeRemaining {
                // Apply more aggressive smoothing for big jumps
                let changeFactor: Double = abs(newEstimate - currentEstimate)
                    > CGFloat(Layout.seconds) ? smoothingFactorLarge : smoothingFactor

                estimatedTimeRemaining = (1 - changeFactor) * currentEstimate +
                    changeFactor * newEstimate
            } else {
                estimatedTimeRemaining = newEstimate
            }
        }

        // Update the last progress
        lastProgressUpdate = (newProgress, now)
    }

    /// Format time remaining into human-readable text
    private func timeRemainingText(from timeInterval: TimeInterval) -> String {
        let minutes: Int = Int(timeInterval) / Layout.seconds
        let seconds: Int = Int(timeInterval) % Layout.seconds

        if minutes > 0 {
            return String(localized: "\(minutes) min \(seconds) sec left", bundle: .module)
        }
        return String(localized: "\(seconds) sec left", bundle: .module)
    }
}

// **MARK: - Preview**
#if DEBUG
    #Preview {
        @Previewable @State var models: [Model] = Model.previews.filter { model in
            model.state?.isDownloading == true
        }
        List(models) { model in
            ModelDownloadProgressView(model: model)
        }
        .padding()
    }
#endif
