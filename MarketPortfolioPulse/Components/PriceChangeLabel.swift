import SwiftUI

/// Animates colour and value between green/red as `change` updates.
struct PriceChangeLabel: View {
    let change: Double
    let changePercent: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
            Text(String(format: "%.2f (%.2f%%)", change, changePercent))
                .contentTransition(.numericText())
        }
        .foregroundStyle(change >= 0 ? Color.green : Color.red)
        .fontWeight(.semibold)
        .animation(.spring(duration: 0.4), value: change)
    }
}

#Preview {
    VStack(spacing: 12) {
        PriceChangeLabel(change: 2.35, changePercent: 1.24)
        PriceChangeLabel(change: -1.10, changePercent: -0.85)
    }
}
