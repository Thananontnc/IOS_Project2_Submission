import SwiftUI

/// Consistent section heading used across the app: title, optional
/// subtitle, and an optional trailing accessory.
struct SectionHeader<Accessory: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.title3.bold())
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            accessory()
        }
    }
}

extension SectionHeader where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Star toggle for watchlist membership.
struct WatchlistStarButton: View {
    let isWatched: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isWatched ? "star.fill" : "star")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isWatched ? Color.yellow : Color.secondary)
                .symbolEffect(.bounce, value: isWatched)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isWatched ? "Remove from watchlist" : "Add to watchlist")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        SectionHeader(title: "Watchlist", subtitle: "3 symbols") {
            WatchlistStarButton(isWatched: true) {}
        }
        SectionHeader(title: "Top Movers", subtitle: "Ranked across 20 large caps")
    }
    .padding()
}
