import Foundation
import SwiftData

/// A card pinned to the top of the Markets screen.
///
/// Was a hardcoded pair of ETFs. Stored now so the user can pin whatever
/// they actually track — a different index, a currency ETF, or a single
/// stock they watch closely.
@Model
final class TrackedIndex {
    @Attribute(.unique) var ticker: String
    var title: String
    /// Manual ordering, so cards keep the position the user put them in.
    var sortIndex: Int

    init(ticker: String, title: String, sortIndex: Int) {
        self.ticker = ticker.uppercased()
        self.title = title
        self.sortIndex = sortIndex
    }
}

extension TrackedIndex {
    /// Shown on a first run, before the user has pinned anything.
    ///
    /// Deliberately a single card. One example plus the visible "Add" tile
    /// reads as an invitation to build your own row; a pre-filled pair
    /// looks finished and hides that the section is editable.
    static let defaults: [(ticker: String, title: String)] = [
        ("SPY", "S&P 500")
    ]

    /// Inserts the starter cards once. Called when the store is empty, so
    /// a user who deliberately removes every card doesn't get them back on
    /// the next launch — an empty list is a valid choice.
    static func seedIfNeeded(existing: [TrackedIndex], context: ModelContext) {
        guard existing.isEmpty,
              !UserDefaults.standard.bool(forKey: "didSeedTrackedIndexes")
        else { return }

        for (offset, item) in defaults.enumerated() {
            context.insert(TrackedIndex(ticker: item.ticker, title: item.title, sortIndex: offset))
        }
        UserDefaults.standard.set(true, forKey: "didSeedTrackedIndexes")
    }

    static func add(
        ticker: String,
        title: String,
        existing: [TrackedIndex],
        context: ModelContext
    ) {
        let key = ticker.uppercased()
        guard !existing.contains(where: { $0.ticker == key }) else { return }
        let nextIndex = (existing.map(\.sortIndex).max() ?? -1) + 1
        context.insert(TrackedIndex(ticker: key, title: title, sortIndex: nextIndex))
    }

    static func remove(_ item: TrackedIndex, context: ModelContext) {
        context.delete(item)
    }
}
