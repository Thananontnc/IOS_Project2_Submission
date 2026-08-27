import SwiftUI

struct RiskAnalysisCard: View {
    let risk: PortfolioRisk?
    let metrics: PortfolioMetrics?
    let isAnalyzing: Bool
    let errorMessage: String?
    var onAnalyze: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let risk {
                riskMeter(risk)

                Text(risk.headline)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(risk.concerns) { concern in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(risk.level.tint)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(concern.title)
                                    .font(.caption.bold())
                                Text(concern.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if let note = risk.diversificationNote, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Text("AI-generated from your holdings. Not financial advice.")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            } else if !isAnalyzing {
                if let metrics {
                    // Show the hard numbers even before any AI call — these
                    // are computed locally and are useful on their own.
                    factRow(metrics)
                }
                Text("Analyse concentration and exposure across your holdings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.snappy(duration: 0.25), value: risk)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
            Text("Risk Analysis")
                .font(.subheadline.bold())
            Spacer()
            if isAnalyzing {
                ProgressView().controlSize(.small)
            } else {
                Button(risk == nil ? "Analyse" : "Refresh", action: onAnalyze)
                    .font(.caption.bold())
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private func riskMeter(_ risk: PortfolioRisk) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(risk.level.label + " risk")
                    .font(.caption.bold())
                    .foregroundStyle(risk.level.tint)
                Spacer()
                Text("\(risk.clampedScore)/100")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(risk.level.tint)
                        .frame(width: geo.size.width * CGFloat(risk.clampedScore) / 100)
                }
            }
            .frame(height: 6)
        }
    }

    private func factRow(_ metrics: PortfolioMetrics) -> some View {
        HStack(spacing: 0) {
            fact("Positions", "\(metrics.positionCount)")
            Divider().frame(height: 26)
            fact("Largest", String(format: "%.0f%%", metrics.largestWeightPercent))
            Divider().frame(height: 26)
            fact("Concentration", concentrationLabel(metrics.concentrationIndex))
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.subheadline.bold())
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// HHI thresholds follow the usual competition-analysis bands.
    private func concentrationLabel(_ hhi: Double) -> String {
        switch hhi {
        case ..<1500:  return "Spread"
        case ..<2500:  return "Medium"
        default:       return "High"
        }
    }
}
