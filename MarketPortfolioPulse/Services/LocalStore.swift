import Foundation

/// Small JSON-file cache in Application Support.
///
/// Used for network responses we want back instantly on the next launch —
/// the app otherwise opens to skeleton rows and stays there until Finnhub
/// replies, which on a 60/min budget can mean seconds of blank screen, or
/// forever with no signal. Cached values are shown immediately and then
/// replaced when fresh data lands.
///
/// Not SwiftData: this is disposable derived data, not user-authored
/// records. Losing it costs a refetch, so it doesn't warrant a schema or
/// migrations. User-authored data (holdings, watchlist) stays in SwiftData.
enum LocalStore {
    private static let directoryName = "Cache"

    private static var directory: URL? {
        guard let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }
        let url = support.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    /// Payload plus the time it was written, so callers can decide whether
    /// a cached value is too old to show.
    struct Stamped<Value: Codable>: Codable {
        let value: Value
        let savedAt: Date
    }

    static func save<Value: Codable>(_ value: Value, as name: String) {
        guard let url = directory?.appendingPathComponent("\(name).json") else { return }
        let stamped = Stamped(value: value, savedAt: Date())
        guard let data = try? JSONEncoder().encode(stamped) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load<Value: Codable>(_ type: Value.Type, as name: String) -> (value: Value, savedAt: Date)? {
        guard let url = directory?.appendingPathComponent("\(name).json"),
              let data = try? Data(contentsOf: url),
              let stamped = try? JSONDecoder().decode(Stamped<Value>.self, from: data)
        else { return nil }
        return (stamped.value, stamped.savedAt)
    }

    static func clear(_ name: String) {
        guard let url = directory?.appendingPathComponent("\(name).json") else { return }
        try? FileManager.default.removeItem(at: url)
    }

    enum Key {
        static let quotes = "quotes"
        static let news = "news"
        static let newsAnalysis = "news-analysis"
    }
}
