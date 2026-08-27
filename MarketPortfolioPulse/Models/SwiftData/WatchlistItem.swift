import Foundation
import SwiftData

@Model
final class WatchlistItem {
    /// Unique so the same ticker can't be starred twice — SwiftData will
    /// upsert rather than insert a duplicate row.
    @Attribute(.unique) var ticker: String
    var addedDate: Date

    init(ticker: String) {
        self.ticker = ticker.uppercased()
        self.addedDate = Date()
    }
}

/// Small helpers so every screen toggles the watchlist the same way.
enum Watchlist {
    static func contains(_ symbol: String, in items: [WatchlistItem]) -> Bool {
        let key = symbol.uppercased()
        return items.contains { $0.ticker == key }
    }

    static func toggle(_ symbol: String, items: [WatchlistItem], context: ModelContext) {
        let key = symbol.uppercased()
        if let existing = items.first(where: { $0.ticker == key }) {
            context.delete(existing)
        } else {
            context.insert(WatchlistItem(ticker: key))
        }
    }

    static func add(_ symbol: String, items: [WatchlistItem], context: ModelContext) {
        let key = symbol.uppercased()
        guard !items.contains(where: { $0.ticker == key }) else { return }
        context.insert(WatchlistItem(ticker: key))
    }
}
