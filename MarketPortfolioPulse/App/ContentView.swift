import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @AppStorage("appTheme") private var themeRaw = AppTheme.system.rawValue

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(1)
            SimulatorView()
                .tabItem { Label("Simulate", systemImage: "chart.xyaxis.line") }
                .tag(2)
            PortfolioView()
                .tabItem { Label("Portfolio", systemImage: "briefcase.fill") }
                .tag(3)
        }
        // nil for .system, so iOS keeps following the device setting.
        .preferredColorScheme(theme.colorScheme)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [PortfolioHolding.self], inMemory: true)
}
