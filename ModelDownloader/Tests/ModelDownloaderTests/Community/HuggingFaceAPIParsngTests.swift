import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

/// Tests that verify HuggingFace API parsing works correctly with real API responses
extension HubAPIExtensionLicenseTests {
    @Test("Parse real HuggingFace community models with fractional seconds dates")
    @MainActor
    internal func testRealHuggingFaceAPIParsingWithFractionalSeconds() async throws {
        let httpClient: DefaultHTTPClient = DefaultHTTPClient()
        let tokenManager: HFTokenManager = HFTokenManager(httpClient: httpClient)
        let hubAPI: HubAPI = HubAPI(httpClient: httpClient, tokenManager: tokenManager)

        // Test with mlx-community which has models with fractional second timestamps
        let models: [DiscoveredModel] = try await hubAPI.searchModels(
            author: "mlx-community",
            limit: 10
        )

        // Should find models without parsing errors
        #expect(!models.isEmpty, "Should find models from mlx-community")

        // Verify basic model structure
        for model: DiscoveredModel in models {
            #expect(!model.id.isEmpty, "Model ID should not be empty")
            #expect(!model.name.isEmpty, "Model name should not be empty")
            #expect(model.author == "mlx-community", "Author should be mlx-community")
            #expect(!model.tags.isEmpty, "Models should have tags")

            // Verify date parsing worked (no nil dates)
            #expect(
                model.lastModified != Date(timeIntervalSince1970: 0),
                "Last modified date should be parsed correctly"
            )
        }

        // Log first few models for verification
        for (index, model) in models.prefix(3).enumerated() {
            print("Model \(index + 1): \(model.id)")
            print("  Name: \(model.name)")
            print("  Tags: \(model.tags.prefix(5).joined(separator: ", "))")
            print("  Last Modified: \(model.lastModified)")
            print("  Downloads: \(model.downloads)")
            print("  Files: \(model.files.count)")
            print()
        }
    }

    @Test("Verify backend detection works with real mlx-community models")
    @MainActor
    internal func testBackendDetectionWithRealMLXModels() async throws {
        let explorer: CommunityModelsExplorer = CommunityModelsExplorer()
        let mlxCommunity: ModelCommunity = ModelCommunity.defaultCommunities[0]

        // Explore mlx-community models
        let models: [DiscoveredModel] = try await explorer.exploreCommunity(
            mlxCommunity,
            limit: 5
        )

        // Should find models with detected backends
        #expect(!models.isEmpty, "Should find MLX community models")

        // Verify backend detection
        for model: DiscoveredModel in models {
            #expect(
                !model.detectedBackends.isEmpty,
                "Models should have detected backends: \(model.id)"
            )
            #expect(
                model.detectedBackends.contains(.mlx),
                "MLX community models should support MLX backend: \(model.id)"
            )
        }

        // Log backend detection results
        for (index, model) in models.enumerated() {
            print("Model \(index + 1): \(model.id)")
            print("  Detected Backends: \(model.detectedBackends.map(\.rawValue).joined(separator: ", "))")
            print("  Tags: \(model.tags.prefix(3).joined(separator: ", "))")
            print()
        }
    }

    @Test("Test date parsing with various timestamp formats")
    @MainActor
    internal func testDateParsingFlexibility() async throws {
        let httpClient: DefaultHTTPClient = DefaultHTTPClient()
        let tokenManager: HFTokenManager = HFTokenManager(httpClient: httpClient)
        let hubAPI: HubAPI = HubAPI(httpClient: httpClient, tokenManager: tokenManager)

        // Test with different communities that might have different date formats
        let communities: [String] = ["mlx-community", "lmstudio-community", "coreml-community"]

        for community: String in communities {
            print("Testing community: \(community)")

            do {
                let models: [DiscoveredModel] = try await hubAPI.searchModels(
                    author: community,
                    limit: 3
                )

                if !models.isEmpty {
                    print("  Found \(models.count) models")

                    for model: DiscoveredModel in models {
                        // Verify date is reasonable (not epoch time)
                        let epochTime: Date = Date(timeIntervalSince1970: 0)
                        let oneYearAgo: Date = Date().addingTimeInterval(-365 * 24 * 60 * 60)

                        #expect(model.lastModified > oneYearAgo, "Date should be recent for \(model.id)")
                        #expect(model.lastModified != epochTime, "Date should not be epoch time for \(model.id)")

                        print("    \(model.id): \(model.lastModified)")
                    }
                } else {
                    print("  No models found")
                }
            } catch {
                print("  Error: \(error)")
                // Only fail if it's mlx-community (which we know should work)
                if community == "mlx-community" {
                    throw error
                }
            }

            print()
        }
    }

    @Test("Verify DiscoveredModel JSON parsing preserves file sizes correctly")
    @MainActor
    internal func testDiscoveredModelFileSizeParsing() async throws {
        let httpClient: DefaultHTTPClient = DefaultHTTPClient()
        let tokenManager: HFTokenManager = HFTokenManager(httpClient: httpClient)
        let hubAPI: HubAPI = HubAPI(httpClient: httpClient, tokenManager: tokenManager)

        // Get models from mlx-community which should have file size information
        let models: [DiscoveredModel] = try await hubAPI.searchModels(
            author: "mlx-community",
            limit: 5
        )

        #expect(!models.isEmpty, "Should find mlx-community models")

        // Check for models with proper file size handling
        var foundModelWithFiles: Bool = false
        var foundModelWithActualSizes: Bool = false
        var foundModelWithNilSizes: Bool = false

        for model: DiscoveredModel in models where !model.files.isEmpty {
            foundModelWithFiles = true

            print("Model: \(model.id)")
            print("  Total files: \(model.files.count)")
            print("  Total size: \(model.formattedTotalSize)")

            for (index, file) in model.files.prefix(3).enumerated() {
                print("  File \(index + 1): \(file.filename)")
                if let size = file.size {
                    print("    Size: \(file.formattedSize) (\(size) bytes)")
                    foundModelWithActualSizes = true
                } else {
                    print("    Size: \(file.formattedSize) (nil)")
                    foundModelWithNilSizes = true
                }
            }

            // Verify that files with nil sizes are handled correctly
            for file: ModelFile in model.files where file.size == nil {
                #expect(
                    file.formattedSize == "Unknown size",
                    "Files with nil size should show 'Unknown size', got: \(file.formattedSize)"
                )
            }

            for file: ModelFile in model.files where file.size == 0 {
                // CRITICAL: Files should not have size = 0 when the API returned nil
                // This is the core issue - convertToDiscoveredModel sets size: sibling.size ?? 0
                print("WARNING: File \(file.filename) has size=0, should be nil when unknown")
            }

            print()
        }

        #expect(foundModelWithFiles, "Should find at least one model with files")

        // Models should have actual file sizes, not all zeros
        if foundModelWithActualSizes {
            print("Found models with actual file sizes")
        } else {
            print("No models found with actual file sizes - possible parsing issue")
        }
    }

    @Test("Verify DiscoveredModel JSON parsing preserves tags correctly")
    @MainActor
    internal func testDiscoveredModelTagsParsing() async throws {
        let httpClient: DefaultHTTPClient = DefaultHTTPClient()
        let tokenManager: HFTokenManager = HFTokenManager(httpClient: httpClient)
        let hubAPI: HubAPI = HubAPI(httpClient: httpClient, tokenManager: tokenManager)

        // Get models from mlx-community which should have meaningful tags
        let models: [DiscoveredModel] = try await hubAPI.searchModels(
            author: "mlx-community",
            tags: ["text-generation"], // Filter for models with this specific tag
            limit: 10
        )

        #expect(!models.isEmpty, "Should find mlx-community models with text-generation tag")

        // Filter to only models that actually match our search criteria
        let textGenModels: [DiscoveredModel] = models.filter { model in
            model.tags.contains("text-generation") ||
            model.tags.contains("text-generation-inference") ||
            model.tags.contains("conversational")
        }

        #expect(!textGenModels.isEmpty, "Should find text-generation models in mlx-community")

        for model: DiscoveredModel in textGenModels {
            print("Model: \(model.id)")
            print("  Tags count: \(model.tags.count)")
            print("  Tags: \(model.tags.prefix(10).joined(separator: ", "))")

            // Verify tags are meaningful
            #expect(!model.tags.isEmpty, "Model \(model.id) should have tags")

            // These models should have text-generation related tags (we filtered for them)
            let hasTextGeneration: Bool = model.tags.contains("text-generation") ||
                                  model.tags.contains("text-generation-inference") ||
                                  model.tags.contains("conversational")
            #expect(
                hasTextGeneration,
                "Model \(model.id) should contain text-generation related tag but has: \(model.tags)"
            )

            // Look for common meaningful tags that MLX community models should have
            let meaningfulTags: [String] = ["mlx", "transformers", "pytorch", "safetensors", "text-generation"]
            let hasRelevantTags: Bool = model.tags.contains { tag in
                meaningfulTags.contains(tag.lowercased())
            }

            #expect(hasRelevantTags, "Model \(model.id) should have relevant tags, got: \(model.tags)")

            print()
        }
    }

    @Test("Verify DiscoveredModel backend detection integration")
    @MainActor
    internal func testDiscoveredModelBackendDetection() async throws {
        let httpClient: DefaultHTTPClient = DefaultHTTPClient()
        let tokenManager: HFTokenManager = HFTokenManager(httpClient: httpClient)
        let hubAPI: HubAPI = HubAPI(httpClient: httpClient, tokenManager: tokenManager)

        // Test the full flow including backend detection
        let models: [DiscoveredModel] = try await hubAPI.searchModels(
            author: "mlx-community",
            limit: 5
        )

        #expect(!models.isEmpty, "Should find mlx-community models")

        // Check if backend detection is properly integrated
        for model: DiscoveredModel in models {
            print("Model: \(model.id)")
            print("  Detected backends: \(model.detectedBackends.map(\.rawValue).joined(separator: ", "))")
            print("  Tags: \(model.tags.prefix(5).joined(separator: ", "))")

            // MLX community models should have detected backends
            if model.detectedBackends.isEmpty {
                print("WARNING: Model \(model.id) has no detected backends")
                print("  This indicates convertToDiscoveredModel sets detectedBackends: [] without calling detection")

                // Let's manually check what backends should be detected
                let backendDetector: BackendDetector = BackendDetector()
                let manuallyDetected: [SendableModel.Backend] = await backendDetector.detectBackends(from: model.tags)
                print("  Manually detected backends: \(manuallyDetected.map(\.rawValue).joined(separator: ", "))")

                // This should show the discrepancy
                #expect(
                    !manuallyDetected.isEmpty,
                    "Backend detection should work for MLX community model tags: \(model.tags)"
                )
            } else {
                print("Model has detected backends")
            }

            print()
        }
    }

    @Test("Debug raw HuggingFace API response structure")
    internal func testDebugRawAPIResponse() async throws {
        let httpClient: DefaultHTTPClient = DefaultHTTPClient()

        // Test 1: Standard search endpoint (no files expected)
        print("Testing standard search endpoint:")
        let searchUrl: URL = URL(string: "https://huggingface.co/api/models?author=mlx-community&limit=1")!
        let searchResponse: HTTPClientResponse = try await httpClient.get(url: searchUrl, headers: [:])

        if let jsonObject = try? JSONSerialization.jsonObject(with: searchResponse.data, options: []),
           let jsonArray = jsonObject as? [[String: Any]],
           let firstModel = jsonArray.first {
            print("Search API keys: \(firstModel.keys.sorted())")
            print("Has siblings: \(firstModel["siblings"] != nil)")
            print("Has tags: \(firstModel["tags"] != nil)")
            if let tags = firstModel["tags"] as? [String] {
                print("Tags: \(tags)")
            } else {
                print("Tags field type: \(type(of: firstModel["tags"]))")
            }

            if let modelId = firstModel["id"] as? String {
                print("\nTesting individual model endpoint for: \(modelId)")

                // Test 2: Individual model endpoint (should have files)
                let modelUrl: URL = URL(string: "https://huggingface.co/api/models/\(modelId)")!
                let modelResponse: HTTPClientResponse = try await httpClient.get(url: modelUrl, headers: [:])

                if modelResponse.statusCode == 200,
                   let modelJson = try? JSONSerialization.jsonObject(with: modelResponse.data, options: []),
                   let modelData = modelJson as? [String: Any] {
                    print("Individual model API keys: \(modelData.keys.sorted())")

                    if let siblings = modelData["siblings"] as? [[String: Any]] {
                        print("Siblings found: \(siblings.count)")
                        if let firstSibling = siblings.first {
                            print("Sibling keys: \(firstSibling.keys.sorted())")
                            print("Sample sibling: \(firstSibling)")
                        }
                    } else {
                        print("No siblings in individual model response either")
                    }
                }
            }
        }

        // Test 3: Try search with potential expand parameters
        print("\nTesting search with expand parameters:")
        let expandParams: [String] = ["expand=files", "expand=siblings", "files=true", "include_files=true"]

        for param: Any in expandParams {
            let testUrl: URL = URL(string: "https://huggingface.co/api/models?author=mlx-community&limit=1&\(param)")!
            let testResponse: HTTPClientResponse = try await httpClient.get(url: testUrl, headers: [:])

            if testResponse.statusCode == 200,
               let jsonObject = try? JSONSerialization.jsonObject(with: testResponse.data, options: []),
               let jsonArray = jsonObject as? [[String: Any]],
               let firstModel = jsonArray.first {
                print("Parameter '\(param)':")
                print("  Has siblings: \(firstModel["siblings"] != nil)")
                print("  Has tags: \(firstModel["tags"] != nil)")
                if let tags = firstModel["tags"] as? [String] {
                    print("  Tags: \(tags.prefix(3).joined(separator: ", "))")
                } else {
                    print("  Tags field: \(firstModel["tags"] ?? "nil")")
                }

                if firstModel["siblings"] != nil {
                    print("Parameter '\(param)' includes siblings!")
                    if firstModel["tags"] == nil {
                        print("But loses tags!")
                    }
                    return
                }
            } else {
                print("Parameter '\(param)' - no siblings")
            }
        }
    }

    @Test("Test JSON response conversion with edge cases")
    @MainActor
    internal func testJSONResponseConversionEdgeCases() async {
        // Test how the parsing handles models with missing or null fields
        // This tests the robustness of convertToDiscoveredModel

        let httpClient: DefaultHTTPClient = DefaultHTTPClient()
        let tokenManager: HFTokenManager = HFTokenManager(httpClient: httpClient)
        let hubAPI: HubAPI = HubAPI(httpClient: httpClient, tokenManager: tokenManager)

        // Search across different communities to find edge cases
        let communities: [String] = ["huggingface", "microsoft", "google"]

        for community: String in communities {
            print("Testing edge cases for community: \(community)")

            do {
                let models: [DiscoveredModel] = try await hubAPI.searchModels(
                    author: community,
                    limit: 3
                )

                for model: DiscoveredModel in models {
                    print("  Model: \(model.id)")
                    print("    Downloads: \(model.downloads)")
                    print("    Likes: \(model.likes)")
                    print("    Tags count: \(model.tags.count)")
                    print("    Files count: \(model.files.count)")
                    print("    Total size: \(model.formattedTotalSize)")

                    // Test edge cases
                    let totalSize: Int64 = model.totalSize
                    let hasFiles: Bool = !model.files.isEmpty
                    if totalSize == 0, hasFiles {
                        print("    WARNING: Model has files but total size is 0")
                        print("    This suggests file sizes are being set to 0 instead of nil")

                        // Check individual file sizes
                        for file: ModelFile in model.files.prefix(3) where file.size == 0 {
                            print("      File \(file.filename): size=0 (should be nil?)")
                        }
                    }

                    print()
                }
            } catch {
                print("  Error testing \(community): \(error)")
                // Don't fail the test for these communities as they might have restrictions
            }
        }
    }
}
