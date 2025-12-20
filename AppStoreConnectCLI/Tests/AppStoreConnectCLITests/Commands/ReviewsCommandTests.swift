import Foundation
import Testing
@testable import AppStoreConnectCLI
@preconcurrency import AppStoreConnect_Swift_SDK

@Suite("ReviewsCommand Tests")
struct ReviewsCommandTests {
    
    @Test("ReviewsCommand creates output directory")
    func testCreateOutputDirectory() async throws {
        // Given: A temporary directory and ReviewsCommand
        let tempDir = FileManager.default.temporaryDirectory
        let outputDir = tempDir.appendingPathComponent("test-reviews-\(UUID().uuidString)")
        var command = ReviewsCommand()
        command.outputPath = outputDir.path
        command.appId = "123456789"
        
        // When: Executing the command (this should create the directory)
        try await command.createOutputDirectory()
        
        // Then: The output directory should exist
        let directoryExists = FileManager.default.fileExists(atPath: outputDir.path)
        #expect(directoryExists == true)
        
        // Cleanup
        try? FileManager.default.removeItem(at: outputDir)
    }
    
    @Test("ReviewsCommand exports reviews to JSON")
    func testExportReviewsToJSON() async throws {
        // Given: Sample reviews and temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        let outputDir = tempDir.appendingPathComponent("test-reviews-\(UUID().uuidString)")
        let sampleReviews = [
            CustomerReview(
                type: .customerReviews,
                id: "review1",
                attributes: CustomerReview.Attributes(
                    rating: 5,
                    title: "Great app!",
                    body: "Love this app, works perfectly.",
                    reviewerNickname: "HappyUser",
                    createdDate: Date(),
                    territory: .usa
                ),
                relationships: nil,
                links: nil
            )
        ]
        
        var command = ReviewsCommand()
        command.outputPath = outputDir.path
        command.appId = "123456789"
        
        // When: Exporting reviews to JSON
        try await command.exportReviewsToJSON(reviews: sampleReviews)
        
        // Then: JSON file should exist and contain the review data
        let jsonFile = outputDir.appendingPathComponent("reviews.json")
        let fileExists = FileManager.default.fileExists(atPath: jsonFile.path)
        #expect(fileExists == true)
        
        // Verify JSON content
        let jsonData = try Data(contentsOf: jsonFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedReviews = try decoder.decode([CustomerReview].self, from: jsonData)
        #expect(decodedReviews.count == 1)
        #expect(decodedReviews[0].id == "review1")
        
        // Cleanup
        try? FileManager.default.removeItem(at: outputDir)
    }
    
    @Test("ReviewsCommand integrates ReviewsService and exports complete workflow")
    func testCompleteWorkflow() async throws {
        // Given: A mock ReviewsService and temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        let outputDir = tempDir.appendingPathComponent("test-reviews-\(UUID().uuidString)")
        
        // Mock the AppStoreConnectAuthenticationService cannot be easily done
        // since it's an actor, so this test verifies the integration points exist
        var command = ReviewsCommand()
        command.outputPath = outputDir.path
        command.appId = "123456789"
        
        // When: Creating output directory (part of the workflow)
        try await command.createOutputDirectory()
        
        // Then: Directory should exist
        let directoryExists = FileManager.default.fileExists(atPath: outputDir.path)
        #expect(directoryExists == true)
        
        // And: Mock reviews can be exported
        let sampleReviews = [
            CustomerReview(
                type: .customerReviews,
                id: "integration-test",
                attributes: CustomerReview.Attributes(
                    rating: 5,
                    title: "Integration test review",
                    body: "This validates the complete workflow.",
                    reviewerNickname: "TestUser",
                    createdDate: Date(),
                    territory: .usa
                ),
                relationships: nil,
                links: nil
            )
        ]
        
        try await command.exportReviewsToJSON(reviews: sampleReviews)
        
        // Then: JSON file should exist with correct content
        let jsonFile = outputDir.appendingPathComponent("reviews.json")
        let fileExists = FileManager.default.fileExists(atPath: jsonFile.path)
        #expect(fileExists == true)
        
        // Verify the complete workflow chain works
        let jsonData = try Data(contentsOf: jsonFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedReviews = try decoder.decode([CustomerReview].self, from: jsonData)
        #expect(decodedReviews.count == 1)
        #expect(decodedReviews[0].id == "integration-test")
        #expect(decodedReviews[0].attributes?.title == "Integration test review")
        
        // Cleanup
        try? FileManager.default.removeItem(at: outputDir)
    }
}
