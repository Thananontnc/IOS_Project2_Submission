import Foundation

/// GET /news?category=general
struct MarketNews: Codable, Identifiable, Equatable {
    let id: Int
    let headline: String
    let summary: String
    let url: String
    let image: String
    let datetime: Int
    let source: String
    /// "top news" or "business" in the general feed. Optional because
    /// company-specific news omits it.
    let category: String?

    var date: Date { Date(timeIntervalSince1970: TimeInterval(datetime)) }

    /// Compact age, e.g. "3h" or "2d" — the feed spans ~60 hours, so a
    /// relative stamp carries more than a wall-clock time.
    var relativeAge: String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h" }
        return "\(Int(seconds / 86_400))d"
    }

    var isTopNews: Bool { category?.lowercased() == "top news" }

    /// True only when `image` is an actual article photo.
    ///
    /// Some publishers (Reuters, for every item) supply no photo and
    /// Finnhub substitutes its own hosted wordmark under
    /// `/finnhub/logo/…` — a 3072x1055 banner. Cropped to fill a square
    /// thumbnail or a 160pt hero it renders as an unreadable slice of
    /// giant letters, which is why those rows looked broken while
    /// publishers with real photos looked fine.
    var hasRealImage: Bool {
        !image.isEmpty && !image.contains("/finnhub/logo/")
    }
}
