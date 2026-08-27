import SwiftUI
import SwiftData

struct AssetDetailView: View {
    let symbol: String

    @State private var viewModel: AssetDetailViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var watchlist: [WatchlistItem]
    @State private var showAddSheet = false
    @State private var showSuccessToast = false

    private var isWatched: Bool { Watchlist.contains(symbol, in: watchlist) }

    /// Remembered across visits and launches — a user who prefers candles
    /// shouldn't re-pick every time they open a stock.
    @AppStorage("chartStyle") private var chartStyleRaw = ChartStyleMode.line.rawValue
    private var chartStyle: ChartStyleMode {
        ChartStyleMode(rawValue: chartStyleRaw) ?? .line
    }

    private var chartStyleToggle: some View {
        HStack(spacing: 2) {
            ForEach(ChartStyleMode.allCases) { mode in
                Button {
                    chartStyleRaw = mode.rawValue
                } label: {
                    Image(systemName: mode.systemImage)
                        .font(.caption.weight(.semibold))
                        .frame(width: 34, height: 26)
                        .background(chartStyle == mode ? Color.accentColor : Color.clear)
                        .foregroundStyle(chartStyle == mode ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(mode.rawValue) chart")
            }
        }
        .padding(2)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .animation(.snappy(duration: 0.2), value: chartStyleRaw)
    }

    init(symbol: String) {
        self.symbol = symbol
        _viewModel = State(initialValue: AssetDetailViewModel(symbol: symbol))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        Task { await viewModel.load() }
                    }
                }

                Group {
                    if let candles = viewModel.candles {
                        VStack(spacing: 8) {
                            HStack {
                                Spacer()
                                chartStyleToggle
                            }
                            PriceChartView(
                                candles: candles,
                                isIntraday: viewModel.selectedPeriod.isIntraday,
                                isMultiYear: viewModel.selectedPeriod.isMultiYear,
                                style: chartStyle
                            )
                        }
                    } else if viewModel.isLoadingChart {
                        ProgressView()
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                    } else if let chartError = viewModel.chartError {
                        VStack(spacing: 8) {
                            Image(systemName: "chart.line.downtrend.xyaxis")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                            Text(chartError)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task { await viewModel.changePeriod(viewModel.selectedPeriod) }
                            }
                            .font(.footnote.bold())
                        }
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.candles?.closes.count)

                periodSelector
                detailSection

                Button {
                    showAddSheet = true
                } label: {
                    Text("Add to Portfolio")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .disabled(viewModel.quote == nil)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .responsiveContainer(maxWidth: 700)
        }
        .navigationTitle(symbol)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Watchlist.toggle(symbol, items: watchlist, context: modelContext)
                } label: {
                    Image(systemName: isWatched ? "star.fill" : "star")
                        .foregroundStyle(isWatched ? Color.yellow : Color.accentColor)
                        .symbolEffect(.bounce, value: isWatched)
                }
                .accessibilityLabel(isWatched ? "Remove from watchlist" : "Add to watchlist")
            }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $showAddSheet) {
            AddToPortfolioSheet(
                symbol: symbol,
                companyName: viewModel.profile?.name ?? symbol,
                currentPrice: viewModel.quote?.c ?? 0
            ) {
                showSuccessToast = true
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    showSuccessToast = false
                }
            }
            .environment(\.modelContext, modelContext)
        }
        .overlay(alignment: .top) {
            if showSuccessToast {
                Label("Added to Portfolio", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .padding()
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring, value: showSuccessToast)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                StockLogoView(
                    symbol: symbol,
                    logoURL: viewModel.profile?.logo,
                    diameter: 44
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(symbol)
                        .font(.title2.bold())
                    if let name = viewModel.profile?.name {
                        Text(name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.bottom, 4)

            if let quote = viewModel.quote {
                Text("$" + quote.c.formatted(.number.precision(.fractionLength(2))))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                ChangeChip(change: quote.d, changePercent: quote.dp)
            } else {
                SkeletonBar(width: 160, height: 40)
            }

            if let extended = viewModel.extendedQuote, extended.isExtendedSession {
                extendedRow(extended)
            }
        }
        .animation(.spring(duration: 0.4), value: viewModel.quote?.c)
    }

    /// Extended-hours print. Shown only outside the regular session — while
    /// the market is open the main quote already carries this.
    private func extendedRow(_ extended: ChartDataService.ExtendedQuote) -> some View {
        HStack(spacing: 7) {
            Image(systemName: extended.session == .pre ? "sunrise.fill" : "moon.stars.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(extended.session.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("$" + extended.price.formatted(.number.precision(.fractionLength(2))))
                .font(.caption.weight(.medium))
            ChangeChip(changePercent: extended.changePercent)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05))
        .clipShape(Capsule())
        .padding(.top, 2)
    }

    /// Single connected segmented control (1D | 1W | 1M | 1Y), matching
    /// the sketch's boxed period selector rather than separate pills.
    private var periodSelector: some View {
        HStack(spacing: 0) {
            ForEach(AssetDetailViewModel.ChartPeriod.allCases, id: \.self) { period in
                Button {
                    Task { await viewModel.changePeriod(period) }
                } label: {
                    Text(period.rawValue)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedPeriod == period
                                ? Color.accentColor
                                : Color.clear
                        )
                        .foregroundStyle(viewModel.selectedPeriod == period ? .white : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
        .animation(.spring(duration: 0.25), value: viewModel.selectedPeriod)
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detail")
                .font(.title3.bold())

            VStack(spacing: 0) {
                if let quote = viewModel.quote {
                    statRow(label: "Open", value: quote.o)
                    Divider()
                    statRow(label: "Prev Close", value: quote.pc)
                    Divider()
                    statRow(label: "Day High", value: quote.h)
                    Divider()
                    statRow(label: "Day Low", value: quote.l)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func statRow(label: String, value: Double) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "$%.2f", value)).fontWeight(.medium)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        AssetDetailView(symbol: "AAPL")
    }
}
