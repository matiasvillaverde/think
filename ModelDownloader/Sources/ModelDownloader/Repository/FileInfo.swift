import Foundation

/// Information about Large File Storage
internal struct LFSInfo: Sendable {
    /// Object ID (SHA256 hash)
    internal let oid: String

    /// File size in bytes
    internal let size: Int64

    /// Pointer file size
    internal let pointerSize: Int
}

/// Information about a file in a HuggingFace repository
internal struct FileInfo: Sendable {
    /// File path relative to repository root
    internal let path: String

    /// File size in bytes
    internal let size: Int64

    /// LFS information if file is stored in LFS
    internal let lfs: LFSInfo?

    /// Whether this file is stored in LFS
    internal var isLFS: Bool {
        lfs != nil
    }

    internal init(path: String, size: Int64, lfs: LFSInfo? = nil) {
        self.path = path
        self.size = size
        self.lfs = lfs
    }

    /// Create FileInfo from JSON dictionary
    static func from(json: [String: Any]) -> Self? {
        guard let path: String = json["path"] as? String else {
            return nil
        }

        let size: Int64
        if let sizeInt64: Int64 = json["size"] as? Int64 {
            size = sizeInt64
        } else if let sizeInt: Int = json["size"] as? Int {
            size = Int64(sizeInt)
        } else {
            return nil
        }

        var lfsInfo: LFSInfo?
        if let lfsData: [String: Any] = json["lfs"] as? [String: Any],
           let oid: String = lfsData["oid"] as? String,
           let pointerSize: Int = lfsData["pointer_size"] as? Int {
            let lfsSize: Int64
            if let sizeInt64: Int64 = lfsData["size"] as? Int64 {
                lfsSize = sizeInt64
            } else if let sizeInt: Int = lfsData["size"] as? Int {
                lfsSize = Int64(sizeInt)
            } else {
                lfsSize = size // Use file size as fallback
            }

            lfsInfo = LFSInfo(
                oid: oid,
                size: lfsSize,
                pointerSize: pointerSize
            )
        }

        return Self(
            path: path,
            size: size,
            lfs: lfsInfo
        )
    }
}
