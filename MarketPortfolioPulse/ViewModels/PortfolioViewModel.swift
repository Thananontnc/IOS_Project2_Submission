import Foundation
import Observation

@MainActor
@Observable
final class PortfolioViewModel {
    var livePrices: [String: Double] = [:]
    var isLoading = false
    var errorMessage: String? = nil

    var risk: PortfolioRisk? = nil
    var isAnalyzingRisk = false
    var riskError: String? = nil

    private let service = FinnhubService.shared
    private let typhoon = TyphoonService.shared

    /// Builds the metric set handed to the model. All arithmetic happens
    /// here so the analysis is interpreting exact figures, not guessing.
    func metrics(for holdings: [PortfolioHolding]) -> PortfolioMetrics? {
        guard !holdings.isEmpty else { return nil }

        let valued = holdings.map { holding -> (PortfolioHolding, Double, Double) in
            let price = livePrices[holding.ticker] ?? holding.averageCost
            return (holding, holding.shares * price, holding.shares * holding.averageCost)
        }

        let totalValue = valued.reduce(0) { $0 + $1.1 }
        let totalCost = valued.reduce(0) { $0 + $1.2 }
        guard totalValue > 0 else { return nil }

        let positions = valued.map { holding, value, cost in
            PortfolioMetrics.Position(
                ticker: holding.ticker,
                name: holding.companyName,
                weightPercent: (value / totalValue) * 100,
                returnPercent: cost > 0 ? ((value - cost) / cost) * 100 : 0,
                marketValue: value
            )
        }

        // Herfindahl-Hirschman Index: sum of squared percentage weights.
        let hhi = positions.reduce(0) { $0 + ($1.weightPercent * $1.weightPercent) }
        let largest = positions.max { $0.weightPercent < $1.weightPercent }

        return PortfolioMetrics(
            totalValue: totalValue,
            totalCost: totalCost,
            totalReturnPercent: totalCost > 0 ? ((totalValue - totalCost) / totalCost) * 100 : 0,
            positionCount: positions.count,
            largestWeightPercent: largest?.weightPercent ?? 0,
            largestTicker: largest?.ticker ?? "—",
            concentrationIndex: hhi,
            positions: positions
        )
    }

    func analyzeRisk(for holdings: [PortfolioHolding]) async {
        guard let metrics = metrics(for: holdings) else { return }
        isAnalyzingRisk = true
        riskError = nil
        do {
            risk = try await typhoon.analyzePortfolioRisk(metrics)
        } catch {
            riskError = error.userFacingMessage
        }
        isAnalyzingRisk = false
    }

    /// Fetches all tickers in parallel via a task group.
    func fetchPrices(for tickers: [String]) async {
        let uniqueTickers = Array(Set(tickers))
        guard !uniqueTickers.isEmpty else { return }
        let service = self.service
        isLoading = true
        errorMessage = nil
        do {
            try await withThrowingTaskGroup(of: (String, Double).self) { group in
                for ticker in uniqueTickers {
                    group.addTask {
                        (ticker, try await service.quote(symbol: ticker).c)
                    }
                }
                for try await (ticker, price) in group {
                    livePrices[ticker] = price
                }
            }
        } catch {
            errorMessage = error.userFacingMessage
        }
        isLoading = false
    }
}
