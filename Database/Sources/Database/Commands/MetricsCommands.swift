import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Metrics Commands

public enum MetricsCommands {
    public struct Add: WriteCommand {
        // MARK: - Properties
        
        /// Logger for metrics add operations
        private static let logger = Logger(
            subsystem: "Database",
            category: "MetricsCommands"
        )
        
        private let messageId: UUID
        private let metrics: ChunkMetrics
        
        // MARK: - Initialization
        
        public init(messageId: UUID, metrics: ChunkMetrics) {
            Self.logger.info("MetricsCommands.Add created for message: \(messageId)")
            self.messageId = messageId
            self.metrics = metrics
        }
        
        // MARK: - Command Execution
        
        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Self.logger.notice("Starting metrics addition for message: \(messageId)")
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            do {
                // Fetch the message
                Self.logger.info("Fetching message with ID: \(messageId)")
                let descriptor = FetchDescriptor<Message>(
                    predicate: #Predicate<Message> { $0.id == messageId }
                )
                
                guard let message = try context.fetch(descriptor).first else {
                    Self.logger.error("Message not found with ID: \(messageId)")
                    throw DatabaseError.messageNotFound
                }
                
                // Check if metrics already exist
                if let existingMetrics = message.metrics {
                    Self.logger.warning("Message already has metrics - ID: \(existingMetrics.id)")
                } else {
                    Self.logger.info("No existing metrics found for message")
                }
                
                // Create new Metrics object from ChunkMetrics
                Self.logger.debug("Creating new Metrics object from ChunkMetrics...")
                let newMetrics = createMetrics(from: metrics)
                
                Self.logger.info("Metrics object created with ID: \(newMetrics.id)")
                
                // Log key metrics
                if let timing = metrics.timing {
                    let totalTime = String(format: "%.2f", timing.totalTime.toTimeInterval())
                    let tps = String(format: "%.1f", timing.tokensPerSecond ?? 0)
                    Self.logger.info("Timing metrics - Total: \(totalTime)s, TPS: \(tps)")
                }
                if let usage = metrics.usage {
                    Self.logger.info(
                        "Usage metrics - Prompt: \(usage.promptTokens ?? 0), Generated: \(usage.generatedTokens)"
                    )
                }
                
                // Attach metrics to message
                Self.logger.debug("Attaching metrics to message...")
                message.metrics = newMetrics
                
                // Insert metrics into context
                Self.logger.debug("Inserting metrics into context...")
                context.insert(newMetrics)
                
                // Save context
                Self.logger.debug("Saving context changes...")
                try context.save()
                
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.notice(
                    "Metrics addition completed successfully in \(String(format: "%.3f", executionTime))s"
                )
                
                return newMetrics.id
            } catch let error as DatabaseError {
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.error(
                    "Database error during metrics addition after \(String(format: "%.3f", executionTime))s: \(error.localizedDescription)"
                )
                throw error
            } catch {
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.error(
                    "Unexpected error during metrics addition after \(String(format: "%.3f", executionTime))s: \(error.localizedDescription)"
                )
                throw error
            }
        }
        
        // MARK: - Private Methods
        
        private func createMetrics(from chunkMetrics: ChunkMetrics) -> Metrics {
            var tokenIds: [Int32] = []
            var tokenTexts: [String] = []
            var tokenLogProbs: [Float32] = []
            var tokenDurations: [TimeInterval] = []
            
            // Extract token information if available
            if let tokens = chunkMetrics.generation?.tokens {
                for token in tokens {
                    tokenIds.append(token.tokenId)
                    tokenTexts.append(token.text)
                    tokenLogProbs.append(token.logProb)
                    tokenDurations.append(token.duration.toTimeInterval())
                }
            }
            
            // Convert token timings
            let tokenTimings: [TimeInterval] = chunkMetrics.timing?.tokenTimings.map { 
                $0.toTimeInterval() 
            } ?? []
            
            // Map stop reason
            let stopReasonString: String? = chunkMetrics.generation?.stopReason.map { 
                switch $0 {
                case .endOfSequence: return "endOfSequence"
                case .maxTokens: return "maxTokens"
                case .stopSequence: return "stopSequence"
                case .userRequested: return "userRequested"
                case .timeout: return "timeout"
                case .error: return "error"
                }
            }
            
            // Calculate derived metrics
            let perplexity = calculatePerplexity(from: tokenLogProbs)
            let entropy = calculateEntropy(from: tokenLogProbs)
            let repetitionRate = calculateRepetitionRate(from: tokenTexts)
            let contextUtilization = calculateContextUtilization(
                used: chunkMetrics.usage?.contextTokensUsed,
                size: chunkMetrics.usage?.contextWindowSize
            )
            let percentiles = calculatePercentiles(from: tokenTimings)
            
            return Metrics(
                totalTime: chunkMetrics.timing?.totalTime.toTimeInterval() ?? 0,
                timeToFirstToken: chunkMetrics.timing?.timeToFirstToken?.toTimeInterval(),
                timeSinceLastToken: chunkMetrics.timing?.timeSinceLastToken?.toTimeInterval(),
                promptProcessingTime: chunkMetrics.timing?.promptProcessingTime?.toTimeInterval(),
                tokenTimings: tokenTimings,
                promptTokens: chunkMetrics.usage?.promptTokens ?? 0,
                generatedTokens: chunkMetrics.usage?.generatedTokens ?? 0,
                totalTokens: chunkMetrics.usage?.totalTokens ?? 0,
                contextWindowSize: chunkMetrics.usage?.contextWindowSize,
                contextTokensUsed: chunkMetrics.usage?.contextTokensUsed,
                kvCacheBytes: chunkMetrics.usage?.kvCacheBytes,
                kvCacheEntries: chunkMetrics.usage?.kvCacheEntries,
                tokenIds: tokenIds,
                tokenTexts: tokenTexts,
                tokenLogProbs: tokenLogProbs,
                tokenDurations: tokenDurations,
                stopReason: stopReasonString,
                temperature: chunkMetrics.generation?.temperature,
                topP: chunkMetrics.generation?.topP,
                topK: chunkMetrics.generation?.topK,
                activeMemory: 0, // Will be set from other sources if available
                cacheMemory: UInt64(chunkMetrics.usage?.kvCacheBytes ?? 0),
                peakMemory: 0, // Will be set from other sources if available
                modelLoadTime: 0, // Will be set from other sources if available
                numParameters: 0, // Will be set from other sources if available
                perplexity: perplexity,
                entropy: entropy,
                repetitionRate: repetitionRate,
                contextUtilization: contextUtilization,
                modelName: nil, // Will be set from message context if available
                timeToFirstTokenP50: percentiles.p50,
                timeToFirstTokenP95: percentiles.p95,
                timeToFirstTokenP99: percentiles.p99
            )
        }
        
        // MARK: - Calculation Methods
        
        private func calculatePerplexity(from logProbs: [Float32]) -> Double? {
            guard !logProbs.isEmpty else { return nil }
            let avgLogProb = logProbs.reduce(0) { $0 + Double($1) } / Double(logProbs.count)
            return exp(-avgLogProb)
        }
        
        private func calculateEntropy(from logProbs: [Float32]) -> Double? {
            guard !logProbs.isEmpty else { return nil }
            var entropy: Double = 0
            for logProb in logProbs {
                let prob = exp(Double(logProb))
                if prob > 0 {
                    entropy -= prob * log2(prob)
                }
            }
            return entropy
        }
        
        private func calculateRepetitionRate(from tokens: [String]) -> Double? {
            guard tokens.count > 1 else { return nil }
            var repetitions = 0
            for index in 1..<tokens.count where tokens[index] == tokens[index-1] {
                repetitions += 1
            }
            return Double(repetitions) / Double(tokens.count - 1)
        }
        
        private func calculateContextUtilization(used: Int?, size: Int?) -> Double? {
            guard let used = used, let size = size, size > 0 else { return nil }
            return Double(used) / Double(size)
        }
        
        private func calculatePercentiles(from timings: [TimeInterval]) -> (p50: Double?, p95: Double?, p99: Double?) {
            guard !timings.isEmpty else { return (nil, nil, nil) }
            let sorted = timings.sorted()
            let count = sorted.count
            
            let p50Index = Int(Double(count) * 0.5)
            let p95Index = Int(Double(count) * 0.95)
            let p99Index = Int(Double(count) * 0.99)
            
            let p50 = sorted[min(p50Index, count - 1)]
            let p95 = sorted[min(p95Index, count - 1)]
            let p99 = sorted[min(p99Index, count - 1)]
            
            return (p50, p95, p99)
        }
    }
    
    public struct Get: ReadCommand {
        // MARK: - Properties
        
        /// Logger for metrics get operations
        private static let logger = Logger(
            subsystem: "Database",
            category: "MetricsCommands"
        )
        
        public typealias Result = Metrics?
        private let messageId: UUID
        
        // MARK: - Initialization
        
        public init(messageId: UUID) {
            Self.logger.info("MetricsCommands.Get created for message: \(messageId)")
            self.messageId = messageId
        }
        
        // MARK: - Command Execution
        
        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Metrics? {
            Self.logger.notice("Starting metrics retrieval for message: \(messageId)")
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            do {
                // Fetch the message
                Self.logger.info("Fetching message with ID: \(messageId)")
                let descriptor = FetchDescriptor<Message>(
                    predicate: #Predicate<Message> { $0.id == messageId }
                )
                
                guard let message = try context.fetch(descriptor).first else {
                    Self.logger.error("Message not found with ID: \(messageId)")
                    throw DatabaseError.messageNotFound
                }
                
                // Get metrics
                let metrics = message.metrics
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                
                if let metricsData = metrics {
                    Self.logger.info("Metrics found - ID: \(metricsData.id)")
                    Self.logger.notice(
                        "Metrics retrieval completed successfully in \(String(format: "%.3f", executionTime))s"
                    )
                } else {
                    Self.logger.info("No metrics found for message")
                    Self.logger.notice(
                        "Metrics retrieval completed in \(String(format: "%.3f", executionTime))s - No metrics"
                    )
                }
                
                return metrics
            } catch let error as DatabaseError {
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.error(
                    "Database error during metrics retrieval after \(String(format: "%.3f", executionTime))s: \(error.localizedDescription)"
                )
                throw error
            } catch {
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.error(
                    "Unexpected error during metrics retrieval after \(String(format: "%.3f", executionTime))s: \(error.localizedDescription)"
                )
                throw error
            }
        }
    }
}

// MARK: - Duration Extension

extension Duration {
    /// Convert Duration to TimeInterval
    func toTimeInterval() -> TimeInterval {
        let components = self.components
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1e18
        return seconds + attoseconds
    }
}