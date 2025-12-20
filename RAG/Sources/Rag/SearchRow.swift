import Abstractions
import Foundation

internal struct SearchRow {
    let distance: Double
    let text: String
    let keywords: String
    let rowId: Int
    let id: UUID

    init(from row: [String: Any]) {
        guard let distance = row["distance"] as? Double,
            let text = row["original_text"] as? String,
            let keywords = row["keywords"] as? String,
            let rowId = row["rowid"] as? Int,
            let id = row["id"] as? String else {
            fatalError("Failed to initialize SearchRow, invalid row: \(row)")
        }

        self.distance = distance
        self.text = text
        self.keywords = keywords
        self.rowId = rowId
        guard let id = UUID(uuidString: id) else {
            fatalError("Failed to initialize UUID, invalid UUID string: \(id)")
        }
        self.id = id
    }

    func toSearchResult() -> SearchResult {
        SearchResult(
            id: id,
            text: text,
            keywords: keywords,
            score: distance,
            rowId: UInt(rowId)
        )
    }
}
