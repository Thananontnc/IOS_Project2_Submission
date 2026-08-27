import Foundation
import SwiftUI

// MARK: - News analysis

/// Structured read of the day's headlines.
///
/// Asked for as JSON rather than prose so the UI can render sentiment,
/// themes and affected tickers as real components — a plain-text blob can
/// only ever be dumped into one `Text`.
struct NewsAnalysis: Codable, Equatable {
    enum Sentiment: String, Codable {
        case bullish, bearish, mixed

        var label: String { rawValue.capitalized }
        var systemImage: String {
            switch self {
            case .bullish: return "arrow.up.right.circle.fill"
            case .bearish: return "arrow.down.right.circle.fill"
            case .mixed:   return "arrow.left.arrow.right.circle.fill"
            }
        }
        var tint: Color {
            switch self {
            case .bullish: return .green
            case .bearish: return .red
            case .mixed:   return .orange
            }
        }
    }

    struct Theme: Codable, Equatable, Identifiable {
        let title: String
        let detail: String
        let tickers: [String]?
        var id: String { title }
        var symbols: [String] { tickers ?? [] }
    }

    let sentiment: Sentiment
    /// -100 (very bearish) to +100 (very bullish).
    let score: Int
    let headline: String
    let themes: [Theme]
    /// What these headlines mean for the user's own symbols, if anything.
    let watchlistNote: String?

    var clampedScore: Int { min(max(score, -100), 100) }
}

// MARK: - Portfolio risk

/// Hard numbers computed in Swift and handed to the model.
///
/// The model interprets; it never derives the figures. Letting an LLM do
/// the arithmetic invites confidently wrong percentages in a screen about
/// someone's money.
struct PortfolioMetrics: Codable {
    struct Position: Codable {
        let ticker: String
        let name: String
        let weightPercent: Double
        let returnPercent: Double
        let marketValue: Double
    }

    let totalValue: Double
    let totalCost: Double
    let totalReturnPercent: Double
    let positionCount: Int
    let largestWeightPercent: Double
    let largestTicker: String
    /// Herfindahl-Hirschman Index over position weights, 0–10,000.
    /// 10,000 means a single holding; under ~1,500 is broadly spread.
    let concentrationIndex: Double
    let positions: [Position]
}

struct PortfolioRisk: Codable, Equatable {
    enum Level: String, Codable {
        case low, moderate, high

        var label: String { rawValue.capitalized }
        var tint: Color {
            switch self {
            case .low:      return .green
            case .moderate: return .orange
            case .high:     return .red
            }
        }
    }

    struct Concern: Codable, Equatable, Identifiable {
        let title: String
        let detail: String
        var id: String { title }
    }

    let level: Level
    /// 0 (very safe) to 100 (very risky).
    let score: Int
    let headline: String
    let concerns: [Concern]
    let diversificationNote: String?

    var clampedScore: Int { min(max(score, 0), 100) }
}
