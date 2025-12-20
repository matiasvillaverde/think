import Abstractions
import Foundation
import Testing

@testable import AgentOrchestrator

/// Tests for the CompactionCoordinator
@Suite("CompactionCoordinator Tests")
internal struct CompactionCoordinatorTests {
    @Test("Calculate utilization returns correct percentage")
    internal func calculateUtilizationReturnsCorrectPercentage() async {
        let coordinator: CompactionCoordinator = CompactionCoordinator()
        let currentTokens: Int = 8_000
        let maxTokens: Int = 10_000

        let utilization: Double = await coordinator.calculateUtilization(
            currentTokens: currentTokens,
            maxTokens: maxTokens
        )

        #expect(utilization == 0.8)
    }

    @Test("Calculate utilization returns zero for zero max tokens")
    internal func calculateUtilizationReturnsZeroForZeroMax() async {
        let coordinator: CompactionCoordinator = CompactionCoordinator()

        let utilization: Double = await coordinator.calculateUtilization(
            currentTokens: 100,
            maxTokens: 0
        )

        #expect(utilization == 0.0)
    }

    @Test("Should trigger memory flush at soft threshold")
    internal func shouldTriggerMemoryFlushAtSoftThreshold() async {
        let config: AgentOrchestratorConfiguration.Compaction = .init(
            softThresholdPercent: 0.80,
            enableAutoFlush: true
        )
        let coordinator: CompactionCoordinator = CompactionCoordinator(config: config)

        let shouldFlush: Bool = await coordinator.shouldTriggerMemoryFlush(utilization: 0.85)

        #expect(shouldFlush)
    }

    @Test("Should not trigger memory flush below soft threshold")
    internal func shouldNotTriggerMemoryFlushBelowThreshold() async {
        let config: AgentOrchestratorConfiguration.Compaction = .init(
            softThresholdPercent: 0.80,
            enableAutoFlush: true
        )
        let coordinator: CompactionCoordinator = CompactionCoordinator(config: config)

        let shouldFlush: Bool = await coordinator.shouldTriggerMemoryFlush(utilization: 0.75)

        #expect(!shouldFlush)
    }

    @Test("Should not trigger memory flush when disabled")
    internal func shouldNotTriggerMemoryFlushWhenDisabled() async {
        let config: AgentOrchestratorConfiguration.Compaction = .init(
            softThresholdPercent: 0.80,
            enableAutoFlush: false
        )
        let coordinator: CompactionCoordinator = CompactionCoordinator(config: config)

        let shouldFlush: Bool = await coordinator.shouldTriggerMemoryFlush(utilization: 0.90)

        #expect(!shouldFlush)
    }

    @Test("Should force compaction at hard threshold")
    internal func shouldForceCompactionAtHardThreshold() async {
        let config: AgentOrchestratorConfiguration.Compaction = .init(
            hardThresholdPercent: 0.95
        )
        let coordinator: CompactionCoordinator = CompactionCoordinator(config: config)

        let shouldCompact: Bool = await coordinator.shouldForceCompaction(utilization: 0.96)

        #expect(shouldCompact)
    }

    @Test("Should not force compaction below hard threshold")
    internal func shouldNotForceCompactionBelowThreshold() async {
        let config: AgentOrchestratorConfiguration.Compaction = .init(
            hardThresholdPercent: 0.95
        )
        let coordinator: CompactionCoordinator = CompactionCoordinator(config: config)

        let shouldCompact: Bool = await coordinator.shouldForceCompaction(utilization: 0.90)

        #expect(!shouldCompact)
    }
}
