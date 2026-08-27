import Foundation

/// The set of symbols the dashboard tracks.
///
/// Finnhub's free tier has no gainers/losers endpoint, so "top movers" is
/// computed client-side: quote every symbol here, then rank by percent
/// change. Names are held statically rather than fetched so rows render
/// instantly and we don't spend ~20 extra profile calls per refresh.
enum MarketUniverse {
    /// Broad-market ETFs shown as index cards. Deliberately excluded from
    /// mover ranking — an index fund by construction moves less than its
    /// constituents, so it would only ever dilute the list.
    static let indexes: [(symbol: String, title: String)] = [
        ("SPY", "S&P 500"),
        ("QQQ", "NASDAQ 100")
    ]

    /// Liquid large caps ranked against each other for movers.
    ///
    /// Deliberately short. Every symbol here costs one call per refresh
    /// against Finnhub's 60/min free budget, shared with news, search and
    /// asset detail — a longer list looks richer but starves the rest of
    /// the app and returns 429s.
    static let movers: [(symbol: String, name: String)] = [
        ("AAPL", "Apple Inc"),
        ("MSFT", "Microsoft Corp"),
        ("NVDA", "NVIDIA Corp"),
        ("GOOGL", "Alphabet Inc"),
        ("AMZN", "Amazon.com Inc"),
        ("META", "Meta Platforms"),
        ("TSLA", "Tesla Inc"),
        ("TSM", "Taiwan Semiconductor"),
        ("AMD", "Advanced Micro Devices"),
        ("ORCL", "Oracle Corp")
    ]

    static let indexSymbols = indexes.map(\.symbol)
    static let moverSymbols = movers.map(\.symbol)
    static let allSymbols = indexSymbols + moverSymbols

    private static let nameLookup: [String: String] = {
        var map = Dictionary(uniqueKeysWithValues: movers.map { ($0.symbol, $0.name) })
        for index in indexes { map[index.symbol] = index.title }
        return map
    }()

    static func name(for symbol: String) -> String {
        nameLookup[symbol] ?? symbol
    }

    static func indexTitle(for symbol: String) -> String {
        indexes.first { $0.symbol == symbol }?.title ?? symbol
    }
}

/// US market session state, used for the dashboard's status pill.
enum MarketSession {
    case open, closed, preMarket, afterHours

    var label: String {
        switch self {
        case .open:       return "Market open"
        case .closed:     return "Market closed"
        case .preMarket:  return "Pre-market"
        case .afterHours: return "After hours"
        }
    }

    var isLive: Bool { self == .open }

    /// Regular session is 09:30–16:00 America/New_York on weekdays.
    /// Holidays aren't modelled — this drives a cosmetic label only.
    static func current(now: Date = Date()) -> MarketSession {
        var calendar = Calendar(identifier: .gregorian)
        guard let eastern = TimeZone(identifier: "America/New_York") else { return .closed }
        calendar.timeZone = eastern

        let components = calendar.dateComponents([.weekday, .hour, .minute], from: now)
        guard let weekday = components.weekday,
              let hour = components.hour,
              let minute = components.minute else { return .closed }

        // weekday: 1 = Sunday, 7 = Saturday
        guard (2...6).contains(weekday) else { return .closed }

        let minutesSinceMidnight = hour * 60 + minute
        switch minutesSinceMidnight {
        case (9 * 60 + 30)..<(16 * 60): return .open
        case (4 * 60)..<(9 * 60 + 30):  return .preMarket
        case (16 * 60)..<(20 * 60):     return .afterHours
        default:                        return .closed
        }
    }
}
