import SwiftUI
import SwiftData

/// Bulk entry for someone moving an existing portfolio across from a
/// broker.
///
/// The per-stock sheet works, but it means navigating to each ticker in
/// turn — tedious for eight positions. This keeps the user in one place:
/// pick a ticker, type shares and cost, add, repeat.
struct PortfolioSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var holdings: [PortfolioHolding]

    @State private var showPicker = false
    @State private var symbol = ""
    @State private var companyName = ""
    @State private var sharesText = ""
    @State private var costText = ""
    @State private var purchaseDate = Date()
    @State private var livePrice: Double?
    @State private var isLoadingPrice = false
    @State private var addedThisSession: [String] = []

    private var shares: Double? {
        let value = Double(sharesText.replacingOccurrences(of: ",", with: "."))
        return (value ?? 0) > 0 ? value : nil
    }
    private var cost: Double? {
        let value = Double(costText.replacingOccurrences(of: ",", with: "."))
        return (value ?? 0) > 0 ? value : nil
    }
    private var canAdd: Bool { !symbol.isEmpty && shares != nil && cost != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Add each position you already own, with the price you actually paid. Buying the same ticker twice merges into one position at a weighted average cost.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Stock") {
                    Button {
                        showPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            if symbol.isEmpty {
                                Image(systemName: "magnifyingglass.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.accentColor)
                                Text("Choose a stock or ETF")
                                    .foregroundStyle(Color.accentColor)
                            } else {
                                StockLogoView(symbol: symbol, diameter: 36)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(symbol).font(.headline)
                                    Text(companyName.isEmpty ? "Tap to change" : companyName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            if isLoadingPrice {
                                ProgressView().controlSize(.small)
                            } else if let livePrice {
                                Text("$" + livePrice.formatted(.number.precision(.fractionLength(2))))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if !symbol.isEmpty {
                    Section("Your position") {
                        LabeledContent("Shares") {
                            TextField("0", text: $sharesText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Cost per share") {
                            HStack(spacing: 2) {
                                Text("$").foregroundStyle(.secondary)
                                TextField("0.00", text: $costText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        DatePicker(
                            "Purchase date",
                            selection: $purchaseDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        // Gregorian regardless of device locale. On a Thai
                        // device this defaults to the Buddhist calendar and
                        // prints "BE 2569" next to USD prices for a US
                        // market — trades settle on Gregorian dates.
                        .environment(\.calendar, Calendar(identifier: .gregorian))

                        if let livePrice, let cost, let shares {
                            let gain = shares * (livePrice - cost)
                            let percent = cost > 0 ? ((livePrice - cost) / cost) * 100 : 0
                            HStack {
                                Text("Unrealised")
                                Spacer()
                                ChangeChip(change: gain, changePercent: percent)
                            }
                        }
                    }

                    Section {
                        Button {
                            addPosition()
                        } label: {
                            Label("Add position", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(!canAdd)
                    }
                }

                if !addedThisSession.isEmpty {
                    Section("Added") {
                        ForEach(addedThisSession, id: \.self) { ticker in
                            HStack(spacing: 10) {
                                StockLogoView(symbol: ticker, diameter: 26)
                                Text(ticker).font(.subheadline.weight(.medium))
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Set up portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .disabled(addedThisSession.isEmpty && holdings.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    // Icon, not the word "Done" — the nav bar already has a
                    // "Done" that finishes setup, and two identical labels
                    // doing different things on one screen is a trap.
                    Button {
                        hideKeyboard()
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                    .accessibilityLabel("Dismiss keyboard")
                }
            }
            .sheet(isPresented: $showPicker) {
                TickerPickerSheet { picked in
                    symbol = picked
                    companyName = MarketUniverse.name(for: picked)
                    Task { await fetchPrice(picked) }
                }
            }
        }
    }

    private func fetchPrice(_ ticker: String) async {
        isLoadingPrice = true
        livePrice = nil
        if let quote = try? await FinnhubService.shared.quote(symbol: ticker), quote.c > 0 {
            livePrice = quote.c
            // Prefill with today's price as a starting point; the user
            // overwrites it with what they actually paid.
            if costText.isEmpty {
                costText = quote.c.formatted(.number.precision(.fractionLength(2)))
            }
        }
        isLoadingPrice = false
    }

    private func addPosition() {
        guard let shares, let cost else { return }
        PortfolioHolding.record(
            ticker: symbol,
            companyName: companyName.isEmpty ? symbol : companyName,
            shares: shares,
            pricePerShare: cost,
            date: purchaseDate,
            existing: holdings,
            context: modelContext
        )
        if !addedThisSession.contains(symbol) {
            addedThisSession.append(symbol)
        }
        // Clear for the next entry but keep the sheet open — the whole
        // point is adding several in a row.
        withAnimation(.snappy) {
            symbol = ""
            companyName = ""
            sharesText = ""
            costText = ""
            livePrice = nil
            purchaseDate = Date()
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }
}
