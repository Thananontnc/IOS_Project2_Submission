import Foundation
import Observation

/// One month along the projection curve.
struct DCAPoint: Identifiable {
    let month: Int
    let invested: Double
    let value: Double
    var id: Int { month }

    var date: Date {
        Calendar.current.date(byAdding: .month, value: month, to: Date()) ?? Date()
    }
}

@MainActor
@Observable
final class SimulatorViewModel {
    // The user's plan is real input, not throwaway UI state — someone who
    // sets up "$750/month into MSFT for 20 years" should find it intact
    // next launch rather than back at the defaults.
    var symbol = "AAPL" {
        didSet { defaults.set(symbol, forKey: Keys.symbol) }
    }
    var monthlyAmount: Double = 500 {
        didSet { defaults.set(monthlyAmount, forKey: Keys.monthly) }
    }
    var years: Int = 10 {
        didSet { defaults.set(years, forKey: Keys.years) }
    }
    var annualReturnPercent: Double = 8 {
        didSet { defaults.set(annualReturnPercent, forKey: Keys.rate) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let symbol = "sim.symbol"
        static let monthly = "sim.monthlyAmount"
        static let years = "sim.years"
        static let rate = "sim.annualReturn"
    }

    init() {
        if let saved = defaults.string(forKey: Keys.symbol), !saved.isEmpty {
            symbol = saved
        }
        // `object(forKey:)` distinguishes "never set" from a stored 0.
        if defaults.object(forKey: Keys.monthly) != nil {
            monthlyAmount = defaults.double(forKey: Keys.monthly)
        }
        if defaults.object(forKey: Keys.years) != nil {
            years = defaults.integer(forKey: Keys.years)
        }
        if defaults.object(forKey: Keys.rate) != nil {
            annualReturnPercent = defaults.double(forKey: Keys.rate)
        }
    }

    var quote: StockQuote? = nil
    var profile: CompanyProfile? = nil
    var isLoadingQuote = false
    var errorMessage: String? = nil

    var aiExplanation: String? = nil
    var isExplaining = false
    var aiError: String? = nil

    private let finnhub = FinnhubService.shared
    private let typhoon = TyphoonService.shared

    var months: Int { years * 12 }

    /// Future value of a monthly contribution stream, compounded monthly.
    /// Each contribution is made at the start of its month, so it earns
    /// return for the whole month it is contributed in.
    var projection: [DCAPoint] {
        let monthlyRate = pow(1 + annualReturnPercent / 100, 1.0 / 12.0) - 1
        var value: Double = 0
        var invested: Double = 0
        var points: [DCAPoint] = [DCAPoint(month: 0, invested: 0, value: 0)]

        for month in 1...max(months, 1) {
            invested += monthlyAmount
            value = (value + monthlyAmount) * (1 + monthlyRate)
            points.append(DCAPoint(month: month, invested: invested, value: value))
        }
        return points
    }

    var totalInvested: Double { projection.last?.invested ?? 0 }
    var projectedValue: Double { projection.last?.value ?? 0 }
    var totalGain: Double { projectedValue - totalInvested }
    var gainPercent: Double {
        totalInvested > 0 ? (totalGain / totalInvested) * 100 : 0
    }

    /// Shares accumulated if every contribution bought at today's price.
    /// A rough illustration only — real DCA buys at varying prices.
    var estimatedShares: Double? {
        guard let price = quote?.c, price > 0 else { return nil }
        return totalInvested / price
    }

    func loadSymbol() async {
        let trimmed = symbol.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmed.isEmpty else { return }
        symbol = trimmed
        isLoadingQuote = true
        errorMessage = nil
        do {
            async let quoteResult = finnhub.quote(symbol: trimmed)
            async let profileResult = finnhub.profile(symbol: trimmed)
            let q = try await quoteResult
            // Profile is only used for the logo/name, so it may fail freely.
            let p = try? await profileResult
            if q.c == 0 {
                errorMessage = "No price found for \(trimmed). Check the ticker symbol."
                quote = nil
                profile = nil
            } else {
                quote = q
                profile = p
            }
        } catch {
            errorMessage = error.userFacingMessage
            quote = nil
        }
        isLoadingQuote = false
    }

    func explainWithAI() async {
        isExplaining = true
        aiError = nil
        do {
            aiExplanation = try await typhoon.explainDCA(
                symbol: symbol,
                monthlyAmount: monthlyAmount,
                years: years,
                annualReturn: annualReturnPercent,
                totalInvested: totalInvested,
                projectedValue: projectedValue
            )
        } catch {
            aiError = error.userFacingMessage
        }
        isExplaining = false
    }
}
