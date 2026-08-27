import Foundation
import Observation

@MainActor
@Observable
final class AssetDetailViewModel {
    var symbol: String
    var profile: CompanyProfile? = nil
    var quote: StockQuote? = nil
    var candles: CandleData? = nil
    /// Persisted alongside the chart style, so both halves of the chart
    /// preference behave the same way across launches.
    var selectedPeriod: ChartPeriod = .oneMonth {
        didSet { UserDefaults.standard.set(selectedPeriod.rawValue, forKey: "chartPeriod") }
    }
    var isLoading = false
    var errorMessage: String? = nil
    /// Chart failures are reported separately so they don't blank the page.
    var chartError: String? = nil

    /// Pre-market / after-hours print, when the market isn't in its
    /// regular session. Best-effort — absence just hides the row.
    var extendedQuote: ChartDataService.ExtendedQuote? = nil

    enum ChartPeriod: String, CaseIterable {
        case oneDay = "1D", oneWeek = "1W", oneMonth = "1M", oneYear = "1Y", fiveYear = "5Y"

        /// Range/interval pair for the chart provider.
        var chartRange: ChartDataService.Range {
            switch self {
            case .oneDay:    return .init(range: "1d",  interval: "5m")
            case .oneWeek:   return .init(range: "5d",  interval: "30m")
            case .oneMonth:  return .init(range: "1mo", interval: "1d")
            case .oneYear:   return .init(range: "1y",  interval: "1wk")
            case .fiveYear:  return .init(range: "5y",  interval: "1wk")
            }
        }

        /// Only a single trading day is labelled by time. 1W uses 30-minute
        /// bars but spans several days, so hour:minute labels there just
        /// repeat "00:00" — it wants dates like the longer ranges.
        var isIntraday: Bool { self == .oneDay }

        /// Multi-year spans label by month/year; month/day repeats too much.
        var isMultiYear: Bool { self == .fiveYear }
    }

    private let service = FinnhubService.shared
    private let chartService = ChartDataService.shared

    init(symbol: String) {
        self.symbol = symbol
        if let raw = UserDefaults.standard.string(forKey: "chartPeriod"),
           let saved = ChartPeriod(rawValue: raw) {
            selectedPeriod = saved
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let profileResult = service.profile(symbol: symbol)
            async let quoteResult = service.quote(symbol: symbol)
            let (p, q) = try await (profileResult, quoteResult)
            profile = p
            quote = q
        } catch {
            errorMessage = error.userFacingMessage
        }
        await loadCandles()
        isLoading = false
        await loadExtendedQuote()
    }

    /// Silent on failure — this is a supplementary row, and Yahoo omits
    /// extended data for some symbols entirely.
    func loadExtendedQuote() async {
        extendedQuote = try? await chartService.extendedQuote(symbol: symbol)
    }

    func changePeriod(_ period: ChartPeriod) async {
        selectedPeriod = period
        await loadCandles()
    }

    func refreshQuote() async {
        do {
            quote = try await service.quote(symbol: symbol)
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    var isLoadingChart = false

    private func loadCandles() async {
        let period = selectedPeriod
        isLoadingChart = true
        defer { isLoadingChart = false }
        do {
            let result = try await chartService.candles(symbol: symbol, range: period.chartRange)
            if result.hasData {
                chartError = nil
                candles = result
            } else {
                chartError = "No chart data for this period."
                candles = nil
            }
        } catch {
            // Keep chart failures out of the page-level banner — the quote
            // and stats are still perfectly usable without a chart.
            if let message = error.userFacingMessage {
                chartError = "Couldn't load the chart. \(message)"
            }
            candles = nil
        }
    }
}
