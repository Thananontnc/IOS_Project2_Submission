import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var pulse = false
    @State private var showSettings = false

    @Query(sort: \WatchlistItem.addedDate, order: .reverse)
    private var watchlist: [WatchlistItem]
    @Query(sort: \TrackedIndex.sortIndex)
    private var trackedIndexes: [TrackedIndex]
    @Environment(\.modelContext) private var modelContext

    @State private var showIndexPicker = false
    @State private var editingIndex: TrackedIndex?

    private var watchedSymbols: [String] { watchlist.map(\.ticker) }
    private var trackedIndexSymbols: [String] { trackedIndexes.map(\.ticker) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    tickerTapeBar

                    VStack(alignment: .leading, spacing: 22) {
                        if let error = viewModel.errorMessage {
                            ErrorBanner(message: error) {
                                Task { await viewModel.loadAll() }
                            }
                        }

                        indexSection
                        watchlistSection
                        moversSection
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Markets")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) { sessionPill }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showIndexPicker) {
                TickerPickerSheet { picked in
                    TrackedIndex.add(
                        ticker: picked,
                        title: MarketUniverse.name(for: picked),
                        existing: trackedIndexes,
                        context: modelContext
                    )
                }
            }
            .sheet(item: $editingIndex) { item in
                RenameIndexSheet(item: item)
            }
            .refreshable { await viewModel.loadAll(force: true) }
            .task {
                TrackedIndex.seedIfNeeded(existing: trackedIndexes, context: modelContext)
                viewModel.watchedSymbols = watchedSymbols
                viewModel.indexSymbols = trackedIndexSymbols
                await viewModel.loadAll()
            }
            // Adding or removing a card changes what needs quoting and
            // charting, so refetch rather than wait for the next tick.
            .onChange(of: trackedIndexSymbols) { _, symbols in
                viewModel.indexSymbols = symbols
                Task { await viewModel.loadAll(force: true) }
            }
            // Auto-refresh only while the US market is actually trading.
            // Quotes don't move when it's shut, and a refresh costs ~22
            // calls against a 60/min budget — polling a closed market is
            // how the app ends up rate-limited.
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 60_000_000_000)
                    guard !Task.isCancelled, viewModel.session.isLive else { continue }
                    await viewModel.loadQuotes()
                }
            }
            // Starring a symbol elsewhere should pull its quote in without
            // waiting for the next 30s refresh.
            .onChange(of: watchedSymbols) { _, symbols in
                viewModel.watchedSymbols = symbols
                Task { await viewModel.loadQuotes() }
            }
            .navigationDestination(for: Mover.self) { mover in
                AssetDetailView(symbol: mover.symbol)
            }
        }
    }

    // MARK: - Watchlist

    @ViewBuilder
    private var watchlistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Watchlist",
                subtitle: watchlist.isEmpty
                    ? "Star a stock to follow it here"
                    : "\(watchlist.count) symbol\(watchlist.count == 1 ? "" : "s")"
            )

            if watchlist.isEmpty {
                watchlistEmptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.watchlistRows.enumerated()), id: \.element.id) { index, row in
                        NavigationLink(value: row) {
                            MoverRowView(
                                symbol: row.symbol,
                                companyName: row.name,
                                price: row.price,
                                changePercent: row.changePercent
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                remove(row.symbol)
                            } label: {
                                Label("Remove from Watchlist", systemImage: "star.slash")
                            }
                        }

                        if index < viewModel.watchlistRows.count - 1 {
                            Divider().padding(.leading, 62)
                        }
                    }

                    // Starred symbols whose quotes haven't arrived yet.
                    if viewModel.watchlistRows.count < watchlist.count {
                        if !viewModel.watchlistRows.isEmpty {
                            Divider().padding(.leading, 62)
                        }
                        MoverSkeletonRow()
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private var watchlistEmptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "star")
                .font(.title3)
                .foregroundStyle(.tertiary)
                .frame(width: 40, height: 40)
                .background(Color.primary.opacity(0.04))
                .clipShape(Circle())

            Text("Tap the star on any stock to keep an eye on it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func remove(_ symbol: String) {
        Watchlist.toggle(symbol, items: watchlist, context: modelContext)
    }

    // MARK: - Session pill

    private var sessionPill: some View {
        let session = viewModel.session
        return HStack(spacing: 5) {
            Circle()
                .fill(session.isLive ? Color.green : Color.secondary)
                .frame(width: 6, height: 6)
                .opacity(session.isLive && pulse ? 0.35 : 1)
                .animation(
                    session.isLive
                        ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                        : .default,
                    value: pulse
                )
            Text(session.label)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(session.isLive ? Color.green : Color.secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background((session.isLive ? Color.green : Color.secondary).opacity(0.12))
        .clipShape(Capsule())
        .onAppear { pulse = true }
    }

    // MARK: - Ticker tape

    private var tickerTapeBar: some View {
        TickerTapeView(items: viewModel.tapeItems)
            .padding(.vertical, 9)
            .background(Color(.secondarySystemGroupedBackground))
            .overlay(alignment: .bottom) {
                Divider().opacity(0.5)
            }
            .overlay(alignment: .top) {
                Divider().opacity(0.5)
            }
    }

    // MARK: - Indexes

    /// Horizontally scrolling because the list is user-editable now — a
    /// fixed two-up row can't grow. Cards keep a consistent width so they
    /// page cleanly rather than sizing to their content.
    private var indexSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if trackedIndexes.isEmpty {
                addIndexTile(fullWidth: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    // Top-aligned and equal-height: a card still waiting on
                    // its sparkline must not sit lower than its neighbours.
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(trackedIndexes) { item in
                            indexCard(symbol: item.ticker, title: item.title)
                                .frame(width: 190)
                                .fixedSize(horizontal: false, vertical: true)
                                .contextMenu {
                                    Button {
                                        editingIndex = item
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        TrackedIndex.remove(item, context: modelContext)
                                    } label: {
                                        Label("Remove card", systemImage: "trash")
                                    }
                                }
                        }

                        addIndexTile(fullWidth: false)
                    }
                    .padding(.horizontal, 16)
                }
                .scrollClipDisabled()
                // Section manages its own horizontal padding so cards can
                // bleed to the screen edge while scrolling.
                .padding(.horizontal, -16)
            }
        }
    }

    private func addIndexTile(fullWidth: Bool) -> some View {
        Button {
            showIndexPicker = true
        } label: {
            VStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                Text(trackedIndexes.isEmpty ? "Add a card" : "Add")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(width: fullWidth ? nil : 96)
            .frame(maxHeight: .infinity)
            .padding(.vertical, fullWidth ? 26 : 0)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        Color.accentColor.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    /// Y-range for a sparkline: tight to the data with a small margin, so
    /// a fraction-of-a-percent move still reads as a shape. Index ETFs
    /// trade near $700 and move a few dollars a day, so any zero-anchored
    /// axis flattens them completely.
    private func sparklineDomain(_ closes: [Double]) -> ClosedRange<Double> {
        guard let low = closes.min(), let high = closes.max() else { return 0...1 }
        guard high > low else {
            // Single distinct value — invent a small band so the line
            // renders mid-card instead of clinging to an edge.
            let pad = max(abs(low) * 0.001, 0.01)
            return (low - pad)...(high + pad)
        }
        let padding = (high - low) * 0.25
        return (low - padding)...(high + padding)
    }

    private func indexCard(symbol: String, title: String) -> some View {
        let quote = viewModel.indexQuote(symbol)
        let closes = viewModel.indexCloses(symbol)
        let isUp = (quote?.d ?? 0) >= 0
        let accent = isUp ? Color.green : Color.red

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                StockLogoView(symbol: symbol, diameter: 22)
                Text(symbol)
                    .font(.subheadline.bold())
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let quote {
                    Text("$" + quote.c.formatted(.number.precision(.fractionLength(2))))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                } else {
                    SkeletonBar(width: 96, height: 24)
                }
            }

            if let quote {
                ChangeChip(change: quote.d, changePercent: quote.dp)
            } else {
                SkeletonBar(width: 74, height: 18)
            }

            // Slot is always reserved, even with no candles yet. Sized to
            // content, a card without a sparkline is shorter than one with
            // it, and the row centre-aligns them into a stagger.
            Group {
                if closes.isEmpty {
                    Color.clear
                } else {
                let domain = sparklineDomain(closes)
                Chart {
                    ForEach(Array(closes.enumerated()), id: \.offset) { i, value in
                        AreaMark(
                            x: .value("Day", i),
                            // Anchored to the domain floor. AreaMark
                            // otherwise baselines at 0, which drags the
                            // y-axis down to 0…766 — against that range a
                            // real 3-dollar move is a dead-flat line.
                            yStart: .value("Floor", domain.lowerBound),
                            yEnd: .value("Price", value)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accent.opacity(0.28), accent.opacity(0.01)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        LineMark(x: .value("Day", i), y: .value("Price", value))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(accent)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                }
                .chartYScale(domain: domain)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                }
            }
            .frame(height: 34)
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(accent.opacity(quote == nil ? 0 : 0.16), lineWidth: 1)
        )
    }

    // MARK: - Movers

    private var moversSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Top Movers",
                subtitle: "Ranked across \(MarketUniverse.moverSymbols.count) large caps"
            )

            Picker("Direction", selection: $viewModel.direction) {
                ForEach(MoverDirection.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.hasMoverData {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.rankedMovers.enumerated()), id: \.element.id) { rank, mover in
                        NavigationLink(value: mover) {
                            MoverRowView(
                                rank: rank + 1,
                                symbol: mover.symbol,
                                companyName: mover.name,
                                price: mover.price,
                                changePercent: mover.changePercent,
                                isWatched: Watchlist.contains(mover.symbol, in: watchlist)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                Watchlist.toggle(mover.symbol, items: watchlist, context: modelContext)
                            } label: {
                                Label(
                                    Watchlist.contains(mover.symbol, in: watchlist)
                                        ? "Remove from Watchlist"
                                        : "Add to Watchlist",
                                    systemImage: Watchlist.contains(mover.symbol, in: watchlist)
                                        ? "star.slash" : "star"
                                )
                            }
                        }

                        if mover.id != viewModel.rankedMovers.last?.id {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .animation(.snappy(duration: 0.28), value: viewModel.direction)
            } else {
                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { index in
                        MoverSkeletonRow()
                        if index < 4 { Divider().padding(.leading, 62) }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }

            if let updated = viewModel.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
            }
        }
    }
}

/// Loading placeholder shaped like a real mover row.
private struct MoverSkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Color.secondary.opacity(0.15)).frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonBar(width: 58, height: 12)
                SkeletonBar(width: 108, height: 10)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                SkeletonBar(width: 62, height: 12)
                SkeletonBar(width: 48, height: 14)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

#Preview {
    DashboardView()
}
