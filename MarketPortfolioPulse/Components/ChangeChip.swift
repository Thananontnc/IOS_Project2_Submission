import SwiftUI

/// Tinted pill showing a price move. Used wherever a change is displayed so
/// gains and losses read identically across the app.
struct ChangeChip: View {
    var change: Double? = nil
    let changePercent: Double
    var showsArrow = true

    private var isUp: Bool { changePercent >= 0 }
    private var tint: Color { isUp ? .green : .red }

    private var text: String {
        let percent = String(format: "%@%.2f%%", isUp ? "+" : "", changePercent)
        guard let change else { return percent }
        return String(format: "%@%.2f · %@", isUp ? "+" : "", change, percent)
    }

    var body: some View {
        HStack(spacing: 3) {
            if showsArrow {
                Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.caption2.weight(.semibold))
                .contentTransition(.numericText())
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(tint.opacity(0.13))
        .clipShape(Capsule())
        .animation(.spring(duration: 0.35), value: changePercent)
    }
}

#Preview {
    VStack(spacing: 10) {
        ChangeChip(change: 2.35, changePercent: 1.24)
        ChangeChip(changePercent: -0.86)
    }
    .padding()
}

/// Horizontal gauge for a -100…+100 sentiment score, centred on zero.
struct SentimentBar: View {
    let score: Int
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let half = geo.size.width / 2
            let magnitude = CGFloat(abs(score)) / 100 * half
            ZStack(alignment: .center) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(tint)
                    .frame(width: max(magnitude, 2))
                    .offset(x: score >= 0 ? magnitude / 2 : -magnitude / 2)
                Rectangle()
                    .fill(Color.primary.opacity(0.25))
                    .frame(width: 1)
            }
        }
        .frame(height: 5)
    }
}
