import SwiftUI

/// Search-as-you-type ticker picker. Backed by the same Finnhub symbol
/// search the Search tab uses, so any listed stock or ETF can be chosen.
struct TickerPickerSheet: View {
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    private let popular = ["AAPL", "MSFT", "NVDA", "GOOGL", "AMZN", "TSLA", "VOO", "SPY", "QQQ", "TSM"]

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section("Popular") {
                        ForEach(popular, id: \.self) { symbol in
                            row(symbol: symbol, name: nil)
                        }
                    }
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                } else if results.isEmpty && !isSearching {
                    Text("No matches for “\(query)”.")
                        .foregroundStyle(.secondary)
                } else {
                    Section(isSearching ? "Searching…" : "Results") {
                        ForEach(results) { result in
                            row(symbol: result.symbol,
                                name: result.description,
                                display: result.displaySymbol)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Choose a ticker")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search stocks and ETFs"
            )
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .onChange(of: query) { _, newValue in scheduleSearch(newValue) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func row(symbol: String, name: String?, display: String? = nil) -> some View {
        Button {
            onSelect(symbol)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                StockLogoView(symbol: symbol, diameter: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(display ?? symbol)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    if let name {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            isSearching = true
            errorMessage = nil
            do {
                let found = try await FinnhubService.shared.symbolSearch(query: trimmed)
                guard !Task.isCancelled else {
                    isSearching = false
                    return
                }
                // Finnhub returns global listings; keep plain equities/ETFs
                // and drop the noisier foreign-exchange duplicates.
                results = Array(found.prefix(30))
            } catch {
                errorMessage = error.userFacingMessage
            }
            isSearching = false
        }
    }
}

#Preview {
    TickerPickerSheet { _ in }
}
