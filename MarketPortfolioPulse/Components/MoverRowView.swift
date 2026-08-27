import SwiftUI

/// A single ranked row in the Top Movers list.
struct MoverRowView: View {
    var rank: Int? = nil
    let symbol: String
    let companyName: String
    let price: Double
    let changePercent: Double
    var logoURL: String? = nil
    var isWatched = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                StockLogoView(symbol: symbol, logoURL: logoURL, diameter: 36)

                if let rank {
                    Text("\(rank)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color(.secondarySystemGroupedBackground), lineWidth: 1.5))
                        .offset(x: -6, y: -6)
                }
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(symbol)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    if isWatched {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.yellow)
                    }
                }
                Text(companyName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text("$" + price.formatted(.number.precision(.fractionLength(2))))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                ChangeChip(changePercent: changePercent)
            }

            Image(systemName: "chevron.right")
                .font(.caption2.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: 0) {
        MoverRowView(rank: 1, symbol: "NVDA", companyName: "NVIDIA Corp", price: 209.66, changePercent: 3.42)
        Divider().padding(.leading, 62)
        MoverRowView(rank: 2, symbol: "V", companyName: "Visa Inc", price: 383.90, changePercent: -0.86)
    }
    .background(Color(.secondarySystemGroupedBackground))
}
