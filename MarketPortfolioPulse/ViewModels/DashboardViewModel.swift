import Foundation
import Observation

/// One ranked row in the Top Movers list.
struct Mover: Identifiable, Hashable {
    let symbol: String
    let name: String
    let quote: StockQuote
    var id: String { symbol }

    static func == (lhs: Mover, rhs: Mover) -> Bool { lhs.symbol == rhs.symbol }
    func hash(into hasher: inout Hasher) { hasher.combine(symbol) }

    var changePercent: Double { quote.dp }
    var price: Double { quote.c }
}

enum MoverDirection: String, CaseIterable, Identifiable {
    case gainers = "Gainers"
    case losers = "Losers"
    var id: String { rawValue }

    var systemImage: String {
        self == .gainers ? "arrow.up.right" : "arrow.down.right"
    }
}

@MainActor
@Observable
final class DashboardViewModel {
    /// One quote map for every tracked symbol. The index cards, the ticker
    /// tape and the movers list are all derived from this, so a refresh
    /// costs one quote per symbol rather than one per symbol per section.
    var quotes: [String: StockQuote] = [:]
    var indexCandles: [String: CandleData] = [:]
    /// Persisted so the Gainers/Losers choice survives a relaunch.
    var direction: MoverDirection = .gainers {
        didSet { UserDefaults.standard.set(direction.rawValue, forKey: "moverDirection") }
    }

    /// True while showing cached prices from a previous launch.
    private(set) var isShowingCachedQuotes = false

    init() {
        if let raw = UserDefaults.standard.string(forKey: "moverDirection"),
           let saved = MoverDirection(rawValue: raw) {
            direction = saved
        }
        // Paint last-known prices immediately rather than skeletons, then
        // let the network replace them.
        if let cached = LocalStore.load([String: StockQuote].self, as: LocalStore.Key.quotes) {
            quotes = cached.value
            lastUpdated = cached.savedAt
            isShowingCachedQuotes = true
        }
    }
    var isLoading = false
    var errorMessage: String? = nil
    var lastUpdated: Date? = nil

    /// Symbols the user has starred. Kept here (rather than queried) so the
    /// quote fetch can cover them alongside the tracked universe in a
    /// single pass; the view pushes the current list in from `@Query`.
    var watchedSymbols: [String] = []

    /// Index cards are user-editable, so the symbol list is pushed in from
    /// the view's @Query rather than read from a constant.
    var indexSymbols: [String] = MarketUniverse.indexSymbols
    var session: MarketSession { MarketSession.current() }

    private let service = FinnhubService.shared

    /// Universe plus watchlist, deduplicated — a starred symbol that's
    /// already tracked costs nothing extra.
    private var symbolsToFetch: [String] {
        var seen = Set<String>()
        return (indexSymbols + MarketUniverse.moverSymbols + watchedSymbols)
            .filter { seen.insert($0).inserted }
    }

    /// Watchlist rows in the order the user added them, newest first.
    var watchlistRows: [Mover] {
        watchedSymbols.compactMap { symbol in
            guard let quote = quotes[symbol], quote.c > 0 else { return nil }
            return Mover(symbol: symbol, name: MarketUniverse.name(for: symbol), quote: quote)
        }
    }

    // MARK: - Derived data

    /// Movers ranked by percent change. Symbols still loading, or quoting
    /// zero (Finnhub's response for an unknown or halted symbol), are
    /// dropped rather than shown as a spurious 0.00% row.
    var rankedMovers: [Mover] {
        let all = MarketUniverse.moverSymbols.compactMap { symbol -> Mover? in
            guard let quote = quotes[symbol], quote.c > 0 else { return nil }
            return Mover(symbol: symbol, name: MarketUniverse.name(for: symbol), quote: quote)
        }
        let sorted = all.sorted { $0.changePercent > $1.changePercent }
        switch direction {
        case .gainers:
            return Array(sorted.filter { $0.changePercent > 0 }.prefix(5))
        case .losers:
            return Array(sorted.filter { $0.changePercent < 0 }.suffix(5).reversed())
        }
    }

    var hasMoverData: Bool {
        MarketUniverse.moverSymbols.contains { (quotes[$0]?.c ?? 0) > 0 }
    }

    /// Tape contents: the user's watchlist leads, with the two index ETFs
    /// as anchors. With an empty watchlist it falls back to the indexes
    /// plus a handful of majors so the tape is never bare.
    var tapeSymbols: [String] {
        var seen = Set<String>()
        let base = watchedSymbols.isEmpty
            ? indexSymbols + Array(MarketUniverse.moverSymbols.prefix(6))
            : watchedSymbols + indexSymbols
        return base.filter { seen.insert($0).inserted }
    }

    var tapeItems: [(symbol: String, price: Double, changePercent: Double)] {
        tapeSymbols.compactMap { symbol in
            guard let quote = quotes[symbol], quote.c > 0 else { return nil }
            return (symbol, quote.c, quote.dp)
        }
    }

    func indexQuote(_ symbol: String) -> StockQuote? { quotes[symbol] }
    func indexCloses(_ symbol: String) -> [Double] {
        Array(indexCandles[symbol]?.closes.suffix(5) ?? [])
    }

    // MARK: - Loading

    /// Skip a refetch when data is still fresh. `.task` fires every time
    /// the tab reappears, and each pass costs one call per tracked symbol
    /// against a 60/min budget — tab-flipping alone could exhaust it.
    private let freshnessWindow: TimeInterval = 45

    private var isFresh: Bool {
        guard let lastUpdated else { return false }
        return Date().timeIntervalSince(lastUpdated) < freshnessWindow
    }

    func loadAll(force: Bool = false) async {
        if force || !isFresh {
            isLoading = true
            errorMessage = nil
            await loadQuotes()
            isLoading = false
        }
        // Deliberately outside the freshness guard. Quotes restore from
        // disk, so `isFresh` can be true on a cold launch while the
        // sparklines have no data at all — gating candles on quote
        // freshness left the index cards permanently chartless.
        if force || indexCandles.isEmpty {
            await loadIndexCandles()
        }
    }

    /// Quotes every tracked symbol in parallel. Individual failures are
    /// tolerated so one bad symbol can't blank the whole dashboard; an
    /// error is only surfaced if nothing at all came back.
    func loadQuotes() async {
        let service = self.service
        let symbols = symbolsToFetch
        var updated = quotes
        var failures: [Error] = []

        await withTaskGroup(of: (String, Result<StockQuote, Error>).self) { group in
            for symbol in symbols {
                group.addTask {
                    do {
                        return (symbol, .success(try await service.quote(symbol: symbol)))
                    } catch {
                        return (symbol, .failure(error))
                    }
                }
            }
            for await (symbol, result) in group {
                switch result {
                case .success(let quote): updated[symbol] = quote
                case .failure(let error): failures.append(error)
                }
            }
        }

        quotes = updated
        if failures.count == symbols.count, let first = failures.first {
            errorMessage = first.userFacingMessage
        } else {
            errorMessage = nil
            lastUpdated = Date()
            isShowingCachedQuotes = false
            LocalStore.save(updated, as: LocalStore.Key.quotes)
        }
    }

    /// Sparklines come from the chart provider rather than Finnhub, whose
    /// candle endpoint 403s on the free tier. They're decoration, so any
    /// failure here stays silent.
    private func loadIndexCandles() async {
        let chartService = ChartDataService.shared
        var updated = indexCandles

        await withTaskGroup(of: (String, CandleData?).self) { group in
            for symbol in indexSymbols {
                group.addTask {
                    (symbol, try? await chartService.candles(
                        symbol: symbol,
                        range: .init(range: "5d", interval: "1d")))
                }
            }
            for await (symbol, candle) in group {
                if let candle, candle.hasData { updated[symbol] = candle }
            }
        }
        indexCandles = updated
    }
}
