import Foundation
import ModelDownloader
import Abstractions

// MARK: - CommunityModelsExplorer Usage Examples

/// Example 1: Basic Model Discovery
/// Demonstrates how to explore communities and discover models
func basicModelDiscoveryExample() async throws {
    print("=== Basic Model Discovery Example ===\n")
    
    let downloader: ModelDownloader = ModelDownloader()
    let explorer = downloader.explorer()
    
    // Get default communities
    let communities = await explorer.getDefaultCommunities()
    print("Available communities:")
    for community in communities  {
        print("- \(community.displayName): \(community.description ?? "")")
    }
    
    // Explore MLX community
    let mlxCommunity = communities[0]
    print("\nExploring \(mlxCommunity.displayName)...")
    
    let models: Data = try await explorer.exploreCommunity(
        mlxCommunity,
        query: "llama",
        sort: .downloads,
        limit: 5
    )
    
    print("Found \(models.count) Llama models:")
    for model in models  {
        print("\n📦 \(model.name)")
        print("   Author: \(model.author)")
        print("   Downloads: \(model.downloads)")
        print("   Size: \(model.formattedTotalSize)")
        print("   Backends: \(model.detectedBackends)")
    }
}

/// Example 2: Search and Download
/// Shows how to search for a model and download it
func searchAndDownloadExample() async throws {
    print("\n=== Search and Download Example ===\n")
    
    let downloader: ModelDownloader = ModelDownloader()
    let explorer = downloader.explorer()
    
    // Search for 4-bit quantized models
    let models: Data = try await explorer.searchByTags(
        ["text-generation", "4bit"],
        community: ModelCommunity.defaultCommunities[0], // mlx-community
        sort: .downloads,
        limit: 3
    )
    
    guard let firstModel: String? = models.first else {
        print("No models found")
        return
    }
    
    print("Selected model: \(firstModel.name)")
    print("Preparing for download...")
    
    // Download the model
    let stream = downloader.download(firstModel)
    
    do {
        for try await event in stream {
            switch event {
            case .progress(let progress):
                print("Progress: \(Int(progress.percentage))% - \(progress.bytesDownloaded) / \(progress.totalBytes) bytes")
                
            case .completed(let modelInfo):
                print("Download completed!")
                print("Model saved to: \(modelInfo.location)")
                print("Format: \(modelInfo.format)")
            }
        }
    } catch {
        print("Download error: \(error)")
    }
}

/// Example 3: Paginated Search
/// Demonstrates how to handle pagination for large result sets
func paginatedSearchExample() async throws {
    print("\n=== Paginated Search Example ===\n")
    
    let explorer: CommunityModelsExplorer = CommunityModelsExplorer()
    
    var allModels: [DiscoveredModel] = []
    var pageNumber: Int = 1
    var cursor: String? = nil
    
    print("Fetching all text generation models...")
    
    repeat {
        let page: Data = try await explorer.searchPaginated(
            query: "text-generation",
            author: "mlx-community",
            sort: .lastModified,
            direction: .descending,
            limit: 20,
            cursor: cursor
        )
        
        allModels.append(contentsOf: page.models)
        cursor = page.nextPageToken
        
        print("Page \(pageNumber): \(page.models.count) models (Total: \(allModels.count))")
        pageNumber += 1
        
    } while cursor != nil && allModels.count < 100 // Limit to 100 for example
    
    print("\nTotal models found: \(allModels.count)")
    
    // Group by backend
    let backendGroups = Dictionary(grouping: allModels) { model in
        model.primaryBackend ?? .mlx
    }
    
    print("\nModels by backend:")
    for (backend, models) in backendGroups {
        print("- \(backend): \(models.count) models")
    }
}

/// Example 4: Model Details and Conversion
/// Shows how to get detailed model information and prepare for download
func modelDetailsExample() async throws {
    print("\n=== Model Details Example ===\n")
    
    let explorer: CommunityModelsExplorer = CommunityModelsExplorer()
    
    // Discover a specific model
    let modelId: String = "mlx-community/Llama-3.2-1B-Instruct-4bit"
    print("Discovering model: \(modelId)")
    
    let model: Data = try await explorer.discoverModel(modelId)
    
    print("\nModel Details:")
    print("Name: \(model.name)")
    print("Author: \(model.author)")
    print("Downloads: \(model.downloads)")
    print("Likes: \(model.likes)")
    print("Last Modified: \(model.lastModified)")
    print("Tags: \(model.tags.joined(separator: ", "))")
    
    print("\nFiles:")
    for file in model.files  {
        print("- \(file.path): \(ByteCountFormatter.string(fromByteCount: file.size ?? 0, countStyle: .file))")
    }
    
    print("\nDetected Backends: \(model.detectedBackends)")
    print("Primary Backend: \(model.primaryBackend ?? .mlx)")
    print("Inferred Type: \(model.inferredModelType ?? .language)")
    
    // Model card preview
    if let modelCard = model.modelCard {
        print("\nModel Card Preview:")
        let preview: String = String(modelCard.prefix(200))
        print(preview + "...")
    }
    
    // Convert to SendableModel
    let sendableModel: Data = try await explorer.prepareForDownload(model)
    print("\n💾 Download Requirements:")
    print("RAM Needed: \(ByteCountFormatter.string(fromByteCount: Int64(sendableModel.ramNeeded), countStyle: .memory))")
    print("Model Type: \(sendableModel.modelType)")
    print("Backend: \(sendableModel.backend)")
}

/// Example 5: Community Comparison
/// Compares models across different communities
func communityComparisonExample() async throws {
    print("\n=== Community Comparison Example ===\n")
    
    let explorer: CommunityModelsExplorer = CommunityModelsExplorer()
    let query: String = "mistral" // Search for Mistral models
    
    print("Searching for '\(query)' models across communities...\n")
    
    for community: Any in ModelCommunity.defaultCommunities  {
        print("\(community.displayName):")
        
        do {
            let models: Data = try await explorer.exploreCommunity(
                community,
                query: query,
                sort: .downloads,
                limit: 3
            )
            
            if models.isEmpty {
                print("   No models found")
            } else {
                for model in models  {
                    print("   - \(model.name)")
                    print("     Downloads: \(model.downloads), Size: \(model.formattedTotalSize)")
                }
            }
        } catch {
            print("   Error: \(error)")
        }
        
        print()
    }
}

/// Example 6: Advanced Filtering
/// Demonstrates complex filtering and model selection
func advancedFilteringExample() async throws {
    print("\n=== Advanced Filtering Example ===\n")
    
    let explorer: CommunityModelsExplorer = CommunityModelsExplorer()
    
    // Search for small, quantized instruction models
    let models: Data = try await explorer.searchByTags(
        ["instruct", "4bit"],
        community: ModelCommunity.defaultCommunities[0],
        sort: .downloads,
        limit: 20
    )
    
    // Filter by size (under 2GB)
    let smallModels: [String] = models.filter { model in
        model.totalSize < 2_147_483_648 // 2GB in bytes
    }
    
    // Filter by specific backends
    let mlxModels: [String] = smallModels.filter { model in
        model.detectedBackends.contains(.mlx)
    }
    
    // Sort by download count
    let sortedModels = mlxModels.sorted { $0.downloads > $1.downloads }
    
    print("Found \(sortedModels.count) small MLX instruction models:")
    
    for (index, model) in sortedModels.prefix(5).enumerated() {
        print("\n\(index + 1). \(model.name)")
        print("   Size: \(model.formattedTotalSize)")
        print("   Downloads: \(model.downloads)")
        print("   Tags: \(model.tags.prefix(3).joined(separator: ", "))")
        
        // Estimate RAM for each
        if let sendable = try? await explorer.prepareForDownload(model) {
             let ramGB: Double = Double(sendable.ramNeeded) / 1_073_741_824
            print("   Estimated RAM: \(String(format: "%.1f", ramGB))GB")
        }
    }
}

/// Example 7: Error Handling
/// Shows proper error handling patterns
func errorHandlingExample() async throws {
    print("\n=== Error Handling Example ===\n")
    
    let explorer: CommunityModelsExplorer = CommunityModelsExplorer()
    let downloader: ModelDownloader = ModelDownloader()
    
    // Example 1: Handle model not found
    do {
        _ = try await explorer.discoverModel("nonexistent/model-that-doesnt-exist")
    } catch HuggingFaceError.repositoryNotFound {
        print("Correctly caught: Model repository not found")
    } catch {
        print("Unexpected error: \(error)")
    }
    
    // Example 2: Handle unsupported format
    let unsupportedModel: DiscoveredModel = DiscoveredModel(
        id: "test/unsupported",
        name: "unsupported",
        author: "test",
        downloads: 0,
        likes: 0,
        tags: [],
        lastModified: Date(),
        files: [ModelFile(path: "model.pkl", size: 1000)],
        detectedBackends: [] // No supported backends
    )
    
    do {
        _ = try await explorer.prepareForDownload(unsupportedModel)
    } catch HuggingFaceError.unsupportedFormat {
        print("Correctly caught: Unsupported model format")
    } catch {
        print("Unexpected error: \(error)")
    }
    
    // Example 3: Handle download errors with retry
    let retryableDownload: () async throws -> Void = {
        let models: Data = try await explorer.exploreCommunity(
            ModelCommunity.defaultCommunities[0],
            query: "tiny", // Look for small models
            limit: 1
        )
        
        guard let model: String? = models.first else { return }
        
        var retryCount: Int = 0
        let maxRetries: Int = 3
        
        while retryCount < maxRetries {
            do {
                let stream = downloader.download(model)
                
                for try await event in stream {
                    switch event {
                    case .completed:
                        print("Download succeeded on attempt \(retryCount + 1)")
                        return
                    case .progress:
                        // Continue processing events
                        break
                    }
                }
            } catch {
                retryCount += 1
                print("Download failed (attempt \(retryCount)/\(maxRetries)): \(error)")
                
                if retryCount < maxRetries {
                    print("Retrying in 2 seconds...")
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
        
        print("Download failed after \(maxRetries) attempts")
    }
    
    // Uncomment to test retry logic
    // try await retryableDownload()
}

/// Example 8: Model Preview and Metadata
/// Shows how to preview models before downloading
func modelPreviewExample() async throws {
    print("\n=== Model Preview Example ===\n")
    
    let explorer: CommunityModelsExplorer = CommunityModelsExplorer()
    
    // Search for vision language models
    let models: Data = try await explorer.searchByTags(
        ["vision", "multimodal"],
        sort: .likes,
        limit: 5
    )
    
    print("Found \(models.count) vision language models\n")
    
    for model in models  {
        print("\(model.name)")
        
        // Get preview without downloading
        let preview = await explorer.getModelPreview(model)
        
        print("  Format: \(preview.format)")
        print("  Size: \(ByteCountFormatter.string(fromByteCount: preview.totalSize, countStyle: .file))")
        print("  Downloaded: \(preview.downloadDate)")
        
        // Metadata
        print("  Metadata:")
        for (key, value) in preview.metadata.sorted(by: { $0.key < $1.key }) {
            print("    - \(key): \(value)")
        }
        
        print()
    }
}

// MARK: - Run All Examples

/// Main function to run all examples
@main
struct CommunityExamples {
    static func main() async {
        print("CommunityModelsExplorer Examples\n")
        
        do {
            // Run examples in sequence
            try await basicModelDiscoveryExample()
            // try await searchAndDownloadExample() // Commented to avoid actual downloads
            try await paginatedSearchExample()
            try await modelDetailsExample()
            try await communityComparisonExample()
            try await advancedFilteringExample()
            try await errorHandlingExample()
            try await modelPreviewExample()
            
            print("\nAll examples completed successfully!")
            
        } catch {
            print("\nExample failed with error: \(error)")
        }
    }
}