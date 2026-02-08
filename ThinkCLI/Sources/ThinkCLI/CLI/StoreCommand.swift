import ArgumentParser
import Foundation

struct StoreCommand: AsyncParsableCommand, GlobalOptionsAccessing {
    static let configuration = CommandConfiguration(
        commandName: "store",
        abstract: "Inspect and reset the local CLI store.",
        subcommands: [Path.self, Reset.self]
    )

    @OptionGroup
    var global: GlobalOptions

    @ParentCommand
    var parent: ThinkCLI

    var parentGlobal: GlobalOptions? { parent.global }
}

extension StoreCommand {
    struct Path: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Print the store base path used by this configuration."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: StoreCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let storeURL = AppStoreLocator.sharedStoreURL(
                bundleId: AppStoreLocator.defaultBundleId,
                overridePath: resolvedGlobal.store
            )
            runtime.output.emit(storeURL.path)
        }
    }

    struct Reset: AsyncParsableCommand, GlobalOptionsAccessing {
        static let configuration = CommandConfiguration(
            abstract: "Delete store artifacts (best-effort)."
        )

        @OptionGroup
        var global: GlobalOptions

        @ParentCommand
        var parent: StoreCommand

        var parentGlobal: GlobalOptions? { parent.resolvedGlobal }

        @Flag(name: .long, help: "Print what would be deleted without deleting.")
        var dryRun: Bool = false

        func run() async throws {
            let runtime = try await CLIRuntimeProvider.runtime(for: resolvedGlobal)
            let storeURL = AppStoreLocator.sharedStoreURL(
                bundleId: AppStoreLocator.defaultBundleId,
                overridePath: resolvedGlobal.store
            )

            let candidates = StoreCommand.buildCandidateStoreURLs(storeURL: storeURL)
            if dryRun {
                let paths = candidates.map(\.path)
                runtime.output.emit(paths, fallback: paths.joined(separator: "\n"))
                return
            }

            let fm = FileManager.default
            var deleted: [String] = []
            for url in candidates where fm.fileExists(atPath: url.path) {
                do {
                    try fm.removeItem(at: url)
                    deleted.append(url.path)
                } catch {
                    // Keep going; report what we successfully removed.
                    continue
                }
            }

            let fallback = deleted.isEmpty
                ? "No store artifacts found."
                : deleted.joined(separator: "\n")
            runtime.output.emit(deleted, fallback: fallback)
        }
    }

    fileprivate static func buildCandidateStoreURLs(storeURL: URL) -> [URL] {
        let baseURL = storeURL.deletingPathExtension()

        var urls: [URL] = []
        urls.append(storeURL)
        urls.append(storeURL.appendingPathExtension("version"))
        urls.append(baseURL.appendingPathExtension("sqlite"))
        urls.append(baseURL.appendingPathExtension("sqlite-wal"))
        urls.append(baseURL.appendingPathExtension("sqlite-shm"))

        // SwiftData often persists SQLite at "<name>.store" for name-based configurations.
        let storeSQLite = storeURL.appendingPathExtension("store")
        urls.append(storeSQLite)
        urls.append(URL(fileURLWithPath: storeSQLite.path + "-wal"))
        urls.append(URL(fileURLWithPath: storeSQLite.path + "-shm"))
        urls.append(storeSQLite.appendingPathExtension("store-wal"))
        urls.append(storeSQLite.appendingPathExtension("store-shm"))

        // Historical variants observed in the field.
        urls.append(storeURL.appendingPathExtension("store-wal"))
        urls.append(storeURL.appendingPathExtension("store-shm"))
        urls.append(URL(fileURLWithPath: storeURL.path + "-wal"))
        urls.append(URL(fileURLWithPath: storeURL.path + "-shm"))

        return Array(Set(urls))
    }
}
