import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("ModelPage Tests")
struct ModelPageTests {
    @Test("ModelPage initialization")
    @MainActor
    func testInitialization() {
        let models: [DiscoveredModel] = [
            createTestModel(id: "model1"),
            createTestModel(id: "model2")
        ]

        let page: ModelPage = ModelPage(
            models: models,
            hasNextPage: true,
            nextPageToken: "next123",
            totalCount: 100
        )

        #expect(page.models == models)
        #expect(page.hasNextPage == true)
        #expect(page.nextPageToken == "next123")
        #expect(page.totalCount == 100)
    }

    @Test("ModelPage without optional values")
    @MainActor
    func testInitializationWithoutOptionals() {
        let models: [DiscoveredModel] = [createTestModel(id: "model1")]

        let page: ModelPage = ModelPage(
            models: models,
            hasNextPage: false
        )

        #expect(page.models == models)
        #expect(page.hasNextPage == false)
        #expect(page.nextPageToken == nil)
        #expect(page.totalCount == nil)
    }

    @Test("Empty page creation")
    func testEmptyPage() {
        let page: ModelPage = ModelPage.empty

        #expect(page.models.isEmpty)
        #expect(page.hasNextPage == false)
        #expect(page.nextPageToken == nil)
        #expect(page.totalCount == nil)
        #expect(page.isEmpty == true)
        #expect(page.isEmpty)
    }

    @Test("Page properties")
    @MainActor
    func testPageProperties() {
        let models: [DiscoveredModel] = [
            createTestModel(id: "model1"),
            createTestModel(id: "model2"),
            createTestModel(id: "model3")
        ]

        let page: ModelPage = ModelPage(models: models, hasNextPage: true)

        #expect(page.isEmpty == false)
        #expect(page.count == 3)
    }

    @Test("Page with no models but hasNextPage")
    func testEmptyPageWithNext() {
        // Edge case: API returns empty page but indicates more pages exist
        let page: ModelPage = ModelPage(
            models: [],
            hasNextPage: true,
            nextPageToken: "token"
        )

        #expect(page.isEmpty == true)
        #expect(page.isEmpty)
        #expect(page.hasNextPage == true)
    }

    // Helper to create test models
    @MainActor
    private func createTestModel(id: String) -> DiscoveredModel {
        DiscoveredModel(
            id: id,
            name: "Test Model",
            author: "test",
            downloads: 100,
            likes: 10,
            tags: ["test"],
            lastModified: Date()
        ) as DiscoveredModel
    }
}
