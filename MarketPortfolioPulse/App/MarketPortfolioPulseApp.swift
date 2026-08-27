import SwiftUI
import SwiftData

@main
struct MarketPortfolioPulseApp: App {
    init() {
        // Company logos and news thumbnails are static files fetched on
        // every screen. The default shared cache is memory-only sized, so
        // they were re-downloaded on each cold launch; a disk cache keeps
        // them across launches and off the network entirely.
        URLCache.shared = URLCache(
            memoryCapacity: 16 * 1024 * 1024,
            diskCapacity: 128 * 1024 * 1024
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [PortfolioHolding.self, WatchlistItem.self, TrackedIndex.self])
    }
}
