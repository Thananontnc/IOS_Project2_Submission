import SwiftUI

private struct TapeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Continuously scrolling price tape.
///
/// The offset is derived from wall-clock time inside a `TimelineView`
/// rather than driven by `withAnimation(.repeatForever)`. A repeating
/// implicit animation gets cancelled whenever the view rebuilds — and this
/// view rebuilds on every quote refresh — which is why the tape would
/// start once and then sit still. Deriving position from elapsed time is
/// immune to that: however often the body re-runs, the tape keeps moving.
struct TickerTapeView: View {
    let items: [(symbol: String, price: Double, changePercent: Double)]
    /// Scroll speed in points per second.
    var speed: Double = 34

    @State private var rowWidth: CGFloat = 0

    private let itemSpacing: CGFloat = 22
    private let loopGap: CGFloat = 22

    private var loopDistance: CGFloat { rowWidth + loopGap }

    var body: some View {
        // The outer GeometryReader is load-bearing. The duplicated,
        // .fixedSize()'d rows are far wider than the screen, and neither
        // .clipped() nor .frame(maxWidth: .infinity) shrinks that: the
        // former only clips drawing, the latter only grows to fill and
        // won't shrink an oversized child. GeometryReader is the one
        // container that adopts the proposed size and ignores its
        // content's, so without it the oversize propagates to the parent
        // stack and the whole page renders wider than the screen.
        GeometryReader { _ in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                HStack(spacing: loopGap) {
                    tapeRow
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(key: TapeWidthKey.self, value: proxy.size.width)
                            }
                        )
                    // Second copy trails the first so the seam is invisible:
                    // once the first has scrolled a full loop, the copy sits
                    // exactly where it started.
                    tapeRow
                }
                .offset(x: currentOffset(at: context.date))
                .frame(maxHeight: .infinity, alignment: .leading)
            }
        }
        .frame(height: 26)
        .clipped()
        .onPreferenceChange(TapeWidthKey.self) { width in
            if width > 0, abs(width - rowWidth) > 0.5 { rowWidth = width }
        }
    }

    private func currentOffset(at date: Date) -> CGFloat {
        guard loopDistance > 1, !items.isEmpty else { return 0 }
        let elapsed = date.timeIntervalSinceReferenceDate
        let travelled = CGFloat(elapsed * speed).truncatingRemainder(dividingBy: loopDistance)
        return -travelled
    }

    private var tapeRow: some View {
        HStack(spacing: itemSpacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 5) {
                    StockLogoView(symbol: item.symbol, diameter: 15)
                    Text(item.symbol)
                        .fontWeight(.bold)
                    Text("$" + item.price.formatted(.number.precision(.fractionLength(2))))
                    Text(String(format: "%@%.2f%%", item.changePercent >= 0 ? "+" : "", item.changePercent))
                        .foregroundStyle(item.changePercent >= 0 ? Color.green : Color.red)
                }
                .font(.system(.caption2, design: .monospaced))
            }
        }
        .fixedSize()
    }
}

#Preview {
    TickerTapeView(items: [
        ("SPY", 560.12, 0.4),
        ("QQQ", 480.55, -0.2),
        ("NVDA", 128.30, 2.8)
    ])
}
