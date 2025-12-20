import Foundation
import ArgumentParser
@preconcurrency import AppStoreConnect_Swift_SDK

/// Command to download customer reviews from App Store Connect
struct ReviewsCommand: AuthenticatedCommand {
    static let configuration = CommandConfiguration(
        commandName: "reviews",
        abstract: "Download customer reviews from App Store Connect",
        discussion: """
        Downloads all customer reviews for a specified app and exports them as JSON.
        Creates an output directory and saves the reviews data for analysis.
        """
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Option(name: .shortAndLong, help: "App Store Connect app ID")
    var appId: String = ""
    
    @Option(name: .shortAndLong, help: "Output directory path")
    var outputPath: String = "./reviews"
    
    func executeAuthenticated(
        authService: AppStoreConnectAuthenticationService,
        context: CLIContext
    ) async throws {
        CLIOutput.section("Downloading Customer Reviews", colored: !globalOptions.noColor)
        
        guard !appId.isEmpty else {
            throw AppStoreConnectError.configurationError(
                message: "App ID is required. Use --app-id to specify the app."
            )
        }
        
        CLIOutput.info("App ID: \(appId)", colored: !globalOptions.noColor)
        CLIOutput.info("Output path: \(outputPath)", colored: !globalOptions.noColor)
        
        // Create the output directory
        try await createOutputDirectory()
        
        // Create ReviewsService and fetch reviews
        let reviewsService = ReviewsService(authService: authService)
        let reviews = try await reviewsService.fetchAllReviews(appId: appId)
        
        CLIOutput.info("Fetched \(reviews.count) reviews", colored: !globalOptions.noColor)
        
        // Export to JSON
        try await exportReviewsToJSON(reviews: reviews)
        
        CLIOutput.success("Reviews exported to \(outputPath)/reviews.json", 
                         colored: !globalOptions.noColor)
    }
    
    /// Creates the output directory for storing reviews
    func createOutputDirectory() async throws {
        let url = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    /// Exports customer reviews to JSON file
    /// - Parameter reviews: Array of customer reviews to export
    func exportReviewsToJSON(reviews: [CustomerReview]) async throws {
        let outputUrl = URL(fileURLWithPath: outputPath)
        
        // Ensure the output directory exists
        try await createOutputDirectory()
        
        let jsonFile = outputUrl.appendingPathComponent("reviews.json")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData = try encoder.encode(reviews)
        try jsonData.write(to: jsonFile)
    }
}
