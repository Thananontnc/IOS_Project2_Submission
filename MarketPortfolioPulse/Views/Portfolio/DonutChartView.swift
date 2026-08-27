import SwiftUI
import Charts

struct DonutChartView: View {
    let slices: [(ticker: String, value: Double)]

    private var total: Double {
        slices.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        if total <= 0 {
            ContentUnavailableView("No Data", systemImage: "chart.pie")
        } else {
            Chart {
                ForEach(slices, id: \.ticker) { slice in
                    SectorMark(
                        angle: .value("Value", slice.value),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Ticker", slice.ticker))
                    .cornerRadius(4)
                }
            }
            .chartLegend(position: .bottom, spacing: 12)
        }
    }
}

#Preview {
    DonutChartView(slices: [("AAPL", 4200), ("NVDA", 3100), ("TSM", 1800)])
        .frame(height: 240)
}
