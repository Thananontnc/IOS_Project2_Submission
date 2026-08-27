import SwiftUI
import SwiftData

struct AddToPortfolioSheet: View {
    let symbol: String
    let companyName: String
    let currentPrice: Double
    var onSave: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var holdings: [PortfolioHolding]

    @State private var sharesText = ""
    @State private var costText = ""
    @State private var purchaseDate = Date()
    @State private var useCurrentPrice = true

    private var shares: Double? {
        let value = Double(sharesText.replacingOccurrences(of: ",", with: "."))
        return (value ?? 0) > 0 ? value : nil
    }

    /// What the user actually paid per share. Defaults to today's price
    /// for a fresh buy, but must stay editable — a position imported from
    /// another broker was bought at a price that has nothing to do with
    /// today's, and forcing it would misstate every P&L figure.
    private var costPerShare: Double? {
        if useCurrentPrice { return currentPrice > 0 ? currentPrice : nil }
        let value = Double(costText.replacingOccurrences(of: ",", with: "."))
        return (value ?? 0) > 0 ? value : nil
    }

    private var existing: PortfolioHolding? {
        holdings.first { $0.ticker == symbol.uppercased() }
    }

    private var canSave: Bool { shares != nil && costPerShare != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        StockLogoView(symbol: symbol, diameter: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(symbol).font(.headline)
                            Text(companyName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("$" + currentPrice.formatted(.number.precision(.fractionLength(2))))
                                .font(.headline)
                            Text("now").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Position") {
                    LabeledContent("Shares") {
                        TextField("0", text: $sharesText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    Toggle("Bought at today's price", isOn: $useCurrentPrice.animation(.snappy))

                    if !useCurrentPrice {
                        LabeledContent("Cost per share") {
                            HStack(spacing: 2) {
                                Text("$").foregroundStyle(.secondary)
                                TextField(
                                    currentPrice.formatted(.number.precision(.fractionLength(2))),
                                    text: $costText
                                )
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
                    }
                }

                if let shares, let cost = costPerShare {
                    Section("Summary") {
                        summaryRow("Total cost", value: shares * cost)
                        summaryRow("Value now", value: shares * currentPrice)

                        let gain = shares * (currentPrice - cost)
                        let percent = cost > 0 ? ((currentPrice - cost) / cost) * 100 : 0
                        HStack {
                            Text(gain >= 0 ? "Unrealised gain" : "Unrealised loss")
                            Spacer()
                            ChangeChip(change: gain, changePercent: percent)
                        }
                    }
                }

                if let existing {
                    Section {
                        Label(
                            "You already hold \(existing.shares.formatted(.number.precision(.fractionLength(0...2)))) shares at $\(existing.averageCost.formatted(.number.precision(.fractionLength(2)))). This will merge into one position with a weighted average cost.",
                            systemImage: "arrow.triangle.merge"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(existing == nil ? "Add \(symbol)" : "Buy more \(symbol)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        hideKeyboard()
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                    .accessibilityLabel("Dismiss keyboard")
                }
            }
        }
        .presentationDetents([.large])
    }

    private func summaryRow(_ label: String, value: Double) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("$" + value.formatted(.number.precision(.fractionLength(2))))
                .foregroundStyle(.secondary)
        }
    }

    private func save() {
        guard let shares, let cost = costPerShare else { return }
        PortfolioHolding.record(
            ticker: symbol,
            companyName: companyName,
            shares: shares,
            pricePerShare: cost,
            date: useCurrentPrice ? Date() : purchaseDate,
            existing: holdings,
            context: modelContext
        )
        dismiss()
        onSave()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }
}
