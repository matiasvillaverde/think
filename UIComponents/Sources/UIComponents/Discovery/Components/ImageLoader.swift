import Foundation
import Kingfisher
import SwiftUI

/// Centralized image loading service for consistent Kingfisher configuration
///
/// Provides standardized image loading with performance optimizations,
/// progressive loading, and consistent error handling across the app.
internal final class ImageLoader: Sendable {
    // MARK: - Singleton

    static let shared: ImageLoader = .init()

    // MARK: - Configuration

    private let defaultCacheExpiration: TimeInterval = Configuration.defaultCacheExpiration
    private let maxDiskCacheSize: UInt = Configuration.maxDiskCacheSize
    private let maxMemoryCacheSize: UInt = Configuration.maxMemoryCacheSize

    // MARK: - Initialization

    private init() {
        configureKingfisher()
    }

    deinit {
        // Cleanup is handled automatically by Kingfisher
    }

    // MARK: - Configuration

    private func configureKingfisher() {
        // Configure memory cache
        ImageCache.default.memoryStorage.config.totalCostLimit = Int(maxMemoryCacheSize)
        ImageCache.default.memoryStorage.config.countLimit = 100

        // Configure disk cache
        ImageCache.default.diskStorage.config.sizeLimit = maxDiskCacheSize
        ImageCache.default.diskStorage.config.expiration = .seconds(defaultCacheExpiration)

        // Configure downloader
        ImageDownloader.default.downloadTimeout = Configuration.downloadTimeout
        ImageDownloader.default.trustedHosts = Set([
            "huggingface.co",
            "cdn-thumbnails.huggingface.co"
        ])
    }

    // MARK: - Image Processing

    /// Creates a downsampling processor for optimal performance
    /// - Parameter targetSize: The target size for the image
    /// - Returns: Configured downsampling processor
    func downsamplingProcessor(for targetSize: CGSize) -> DownsamplingImageProcessor {
        DownsamplingImageProcessor(size: targetSize)
    }

    /// Creates a blur processor for progressive loading placeholder
    /// - Parameter radius: Blur radius (default: Configuration.defaultBlurRadius)
    /// - Returns: Configured blur processor
    func blurProcessor(
        radius: CGFloat = Configuration.defaultBlurRadius
    ) -> BlurImageProcessor {
        BlurImageProcessor(blurRadius: radius)
    }

    /// Creates a combined processor for optimized progressive loading
    /// - Parameters:
    ///   - targetSize: Target size for downsampling
    ///   - blurRadius: Blur radius for progressive effect
    /// - Returns: Combined processor pipeline
    func progressiveProcessor(
        targetSize: CGSize,
        blurRadius: CGFloat = Configuration.progressiveBlurRadius
    ) -> ImageProcessor {
        let downsample: DownsamplingImageProcessor = downsamplingProcessor(for: targetSize)
        let blur: BlurImageProcessor = blurProcessor(radius: blurRadius)
        return downsample |> blur
    }

    // MARK: - Prefetching

    /// Prefetches images for improved performance
    /// - Parameters:
    ///   - urls: Array of URLs to prefetch
    ///   - targetSize: Target size for optimization
    func prefetchImages(urls: [URL], targetSize: CGSize) {
        let processor: DownsamplingImageProcessor = downsamplingProcessor(for: targetSize)
        let prefetcher: ImagePrefetcher = ImagePrefetcher(
            urls: urls,
            options: [
                .processor(processor),
                .cacheOriginalImage
            ]
        )
        prefetcher.start()
    }

    /// Stops prefetching for given URLs
    /// - Parameter urls: URLs to stop prefetching
    func stopPrefetching(urls: [URL]) {
        ImagePrefetcher(urls: urls).stop()
    }

    // MARK: - Cache Management

    /// Clears image cache if needed (low memory situations)
    func clearCacheIfNeeded() {
        ImageCache.default.clearMemoryCache()
    }

    // MARK: - Image Loading Options

    /// Standard options for Discovery card images
    var cardImageOptions: KingfisherOptionsInfo {
        [
            .cacheOriginalImage,
            .backgroundDecode,
            .transition(.fade(Configuration.cardFadeDuration))
        ]
    }

    /// Options for detail view images with progressive loading
    func detailImageOptions(targetSize: CGSize) -> KingfisherOptionsInfo {
        [
            .processor(downsamplingProcessor(for: targetSize)),
            .cacheOriginalImage,
            .backgroundDecode,
            .transition(.fade(Configuration.detailFadeDuration))
        ]
    }

    /// Options for progressive loading (blur-to-sharp effect)
    func progressiveImageOptions(targetSize: CGSize) -> KingfisherOptionsInfo {
        [
            .processor(progressiveProcessor(targetSize: targetSize)),
            .cacheOriginalImage,
            .backgroundDecode,
            .transition(.fade(Configuration.progressiveFadeDuration))
        ]
    }
}

// MARK: - Configuration Constants

private enum Configuration {
    static let daysInCacheExpiration: Int = 14
    static let hoursInDay: Int = 24
    static let minutesInHour: Int = 60
    static let secondsInMinute: Int = 60
    static let defaultCacheExpiration: TimeInterval = .init(
        daysInCacheExpiration * hoursInDay * minutesInHour * secondsInMinute
    )

    static let kbMultiplier: UInt = 1_024
    static let mbToBytesMultiplier: UInt = kbMultiplier * kbMultiplier
    static let maxDiskCacheMB: UInt = 100
    static let maxMemoryCacheMB: UInt = 50
    static let maxDiskCacheSize: UInt = maxDiskCacheMB * mbToBytesMultiplier
    static let maxMemoryCacheSize: UInt = maxMemoryCacheMB * mbToBytesMultiplier

    static let downloadTimeoutSeconds: Double = 30.0
    static let downloadTimeout: TimeInterval = downloadTimeoutSeconds
    static let defaultBlurRadius: CGFloat = 10
    static let progressiveBlurRadius: CGFloat = 8
    static let cardFadeDuration: Double = 0.25
    static let detailFadeDuration: Double = 0.3
    static let progressiveFadeDuration: Double = 0.2
}
