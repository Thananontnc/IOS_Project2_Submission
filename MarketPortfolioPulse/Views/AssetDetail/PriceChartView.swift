import SwiftUI
import Charts

/// Line/area versus OHLC candlesticks.
enum ChartStyleMode: String, CaseIterable, Identifiable {
    case line = "Line"
    case candle = "Candles"
    var id: String { rawValue }

    var systemImage: String {
        self == .line ? "chart.xyaxis.line" : "chart.bar.fill"
    }
}

struct PriceChartView: View {
    let candles: CandleData
    /// Drives the x-axis label format — a single trading day is labelled by
    /// time, anything longer by date.
    var isIntraday = false
    /// Multi-year ranges label by month/year instead of month/day.
    var isMultiYear = false
    var style: ChartStyleMode = .line

    @State private var selected: Point?

    struct Point: Identifiable, Equatable {
        let id: Int
        let date: Date
        let close: Double
        let open: Double
        let high: Double
        let low: Double

        var isUp: Bool { close >= open }
    }

    /// Built once per value change rather than recomputed on every access —
    /// the drag handler hits this on each gesture update.
    private var points: [Point] {
        let t = candles.timestamps
        let c = candles.closes
        let o = candles.opens
        let h = candles.highs
        let l = candles.lows

        return (0..<min(t.count, c.count)).map { index in
            let close = c[index]
            return Point(
                id: index,
                date: Date(timeIntervalSince1970: TimeInterval(t[index])),
                close: close,
                // Yahoo can omit a series; fall back to close so a candle
                // degrades to a flat mark instead of drawing at zero.
                open: index < o.count ? o[index] : close,
                high: index < h.count ? h[index] : close,
                low: index < l.count ? l[index] : close
            )
        }
    }

    private var isUp: Bool {
        guard let first = candles.closes.first, let last = candles.closes.last else { return true }
        return last >= first
    }

    private var lineColor: Color { isUp ? .green : .red }

    /// Zoom the y-axis to the data instead of anchoring at zero. A stock
    /// trading in a $10 band on a 0-based axis renders as a flat line.
    private var priceDomain: ClosedRange<Double> {
        // Candles need the wick extremes in range, not just closes —
        // scaling to closes alone clips the high/low tails.
        let lows = style == .candle ? points.map(\.low) : candles.closes
        let highs = style == .candle ? points.map(\.high) : candles.closes
        guard let low = lows.min(), let high = highs.max(), high > low else {
            let value = candles.closes.first ?? 0
            return (value * 0.99)...(value * 1.01 + 0.01)
        }
        let padding = (high - low) * 0.10
        return (low - padding)...(high + padding)
    }

    /// Decimal places that keep axis labels distinct. A tight intraday band
    /// rounded to whole dollars prints the same number several times.
    private var priceFractionDigits: Int {
        let span = priceDomain.upperBound - priceDomain.lowerBound
        if span < 1 { return 3 }
        if span < 20 { return 2 }
        return 0
    }

    /// Candle body width, scaled to how many bars are on screen. 5Y packs
    /// 263 bars into ~340pt, so a fixed width would overlap into a solid block.
    private var candleWidth: CGFloat {
        let count = max(points.count, 1)
        switch count {
        case ..<40:   return 7
        case ..<90:   return 4
        case ..<160:  return 2.5
        default:      return 1.6
        }
    }

    /// Minimum body height so open == close still draws a visible line.
    private var bodyEpsilon: Double {
        (priceDomain.upperBound - priceDomain.lowerBound) * 0.002
    }

    private var xAxisFormat: Date.FormatStyle {
        if isIntraday { return .dateTime.hour().minute() }
        if isMultiYear { return .dateTime.month(.abbreviated).year(.twoDigits) }
        return .dateTime.month(.abbreviated).day()
    }

    var body: some View {
        Chart {
            if style == .line {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Time", point.date),
                        // Anchor the fill to the visible floor. Left to
                        // default it starts at zero, far below the zoomed
                        // domain, and the gradient's fade lands off-screen.
                        yStart: .value("Floor", priceDomain.lowerBound),
                        yEnd: .value("Price", point.close)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [lineColor.opacity(0.28), lineColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                ForEach(points) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Price", point.close)
                    )
                    // monotone, not catmullRom: Catmull-Rom overshoots past
                    // the real min/max between points, inventing highs and
                    // lows the stock never traded at, and the overshoot
                    // clips against the zoomed y-domain.
                    .interpolationMethod(.monotone)
                    .foregroundStyle(lineColor)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            } else {
                ForEach(points) { point in
                    // Wick: full high-low range, drawn thin behind the body.
                    RectangleMark(
                        x: .value("Time", point.date),
                        yStart: .value("Low", point.low),
                        yEnd: .value("High", point.high),
                        width: .fixed(1.2)
                    )
                    .foregroundStyle(point.isUp ? Color.green : Color.red)

                    // Body: open-to-close. Given a minimum height so a
                    // doji (open == close) still renders as a visible line
                    // rather than vanishing.
                    RectangleMark(
                        x: .value("Time", point.date),
                        yStart: .value("Open", min(point.open, point.close)),
                        yEnd: .value("Close", max(point.open, point.close) + bodyEpsilon),
                        width: .fixed(candleWidth)
                    )
                    .foregroundStyle(point.isUp ? Color.green : Color.red)
                    .cornerRadius(1)
                }
            }

            if let selected {
                RuleMark(x: .value("Time", selected.date))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(
                        position: .top,
                        spacing: 4,
                        // Without this the callout is clipped at the chart's
                        // left and right edges.
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("$" + selected.close.formatted(.number.precision(.fractionLength(2))))
                                .font(.caption.bold())
                            if style == .candle {
                                Text("O \(selected.open, format: .number.precision(.fractionLength(2)))  H \(selected.high, format: .number.precision(.fractionLength(2)))  L \(selected.low, format: .number.precision(.fractionLength(2)))")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Text(selected.date, format: isIntraday
                                 ? .dateTime.hour().minute()
                                 : .dateTime.month(.abbreviated).day().year(.twoDigits))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }

                if style == .line {
                    PointMark(
                        x: .value("Time", selected.date),
                        y: .value("Price", selected.close)
                    )
                    .symbolSize(90)
                    .foregroundStyle(lineColor)
                }
            }
        }
        .chartYScale(domain: priceDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: xAxisFormat)
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text("$" + price.formatted(.number.precision(.fractionLength(priceFractionDigits))))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateSelection(at: value.location, proxy: proxy, geo: geo)
                            }
                            .onEnded { _ in selected = nil }
                    )
            }
        }
        .frame(height: 220)
        // Room for the callout so it isn't cropped by the parent stack.
        .padding(.top, 26)
    }

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let origin = geo[plotFrame].origin
        let xPosition = location.x - origin.x
        guard let date: Date = proxy.value(atX: xPosition) else { return }
        let match = points.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
        if match != selected { selected = match }
    }
}
