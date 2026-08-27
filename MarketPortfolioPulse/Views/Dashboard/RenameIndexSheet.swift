import SwiftUI
import SwiftData

/// Lets the user relabel a pinned card. The ticker is fixed — only the
/// caption changes, so "SPY / S&P 500" can become "SPY / My benchmark".
struct RenameIndexSheet: View {
    let item: TrackedIndex

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        StockLogoView(symbol: item.ticker, diameter: 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.ticker).font(.headline)
                            Text("Card label")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Section("Label") {
                    TextField("e.g. S&P 500", text: $title)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Rename card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = title.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty { item.title = trimmed }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { title = item.title }
        }
        .presentationDetents([.medium])
    }
}
