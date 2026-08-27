# Market & Portfolio Pulse

A multi-screen iOS app for tracking stock prices, researching companies,
simulating a dollar-cost-averaging plan, and managing a portfolio.

Built with SwiftUI, SwiftData and Swift Charts.

---

## Running the app

1. Unzip the archive.
2. Open `MarketPortfolioPulse.xcodeproj` in Xcode.
3. Select any iPhone simulator (built and tested on **iPhone 17, iOS 26.5**).
4. Press **Run** (⌘R).

No dependencies, no package manager, no configuration. API keys are already
included in `Constants/APIConstants.swift`, so the app fetches live market
data on first launch.

**Requires an internet connection.** Prices, news and charts all come from
live APIs.

`project.yml` is an [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec
used to generate the Xcode project during development. It is **not needed
to build or run** — the `.xcodeproj` is self-contained.

---

## Screens

| Screen | What it does |
|---|---|
| **Markets** | Editable index cards, watchlist, live ticker tape, ranked top movers |
| **Search** | Symbol search, AI market brief, filterable news feed |
| **Simulate** | Dollar-cost-averaging projection with an interactive chart |
| **Portfolio** | Holdings, allocation donut, AI risk analysis |
| **Asset Detail** | Price chart (line/candlestick), period selector, company stats |
| **Settings** | Theme picker, stored-data summary, cache controls |

Plus modal sheets: portfolio setup, add position, ticker picker, rename card.

---

## Technical requirements

### 1. External API integration

Three live REST APIs, all via `URLSession` + `async/await`, decoded with
`Codable`:

- **Finnhub** — quotes, symbol search, company profiles, market news
- **Yahoo Finance** — historical candles, pre-market / after-hours prices
- **Typhoon (LLM)** — AI news analysis and portfolio risk assessment

Supporting detail:

- `Services/FinnhubService.swift` — typed errors, automatic retry on HTTP 429
- `Services/RateLimiter.swift` — client-side rolling-window limiter that
  reads the server's own `x-ratelimit-remaining` / `x-ratelimit-reset`
  headers to stay inside the free tier's 60 requests/minute
- `Services/ErrorHandling.swift` — task cancellation is filtered out so
  normal SwiftUI teardown never surfaces as a user-facing error
- Failures show an inline retry banner rather than blocking the screen

### 2. Data persistence

Three layers, chosen per kind of data:

**SwiftData** — user-authored records that deserve a schema:
- `PortfolioHolding` — ticker, shares, average cost, purchase date
- `WatchlistItem` — starred symbols
- `TrackedIndex` — pinned cards on the Markets screen

**UserDefaults** — small preferences: theme, chart style and period,
DCA plan inputs, recent searches.

**JSON file cache + URLCache** (`Services/LocalStore.swift`) — quotes, news
and AI analysis, so the app shows content immediately on launch instead of
empty skeletons. Deliberately not SwiftData: this is disposable derived
data, and losing it costs only a refetch.

### 3. Advanced UI

- Swift Charts: line, **candlestick**, donut, and sparklines
- Interactive chart with drag-to-inspect crosshair and OHLC callout
- Continuously scrolling ticker tape driven by `TimelineView`
- Full dark / light / system theming
- Skeleton loading states, spring animations, `contentTransition(.numericText())`
- Custom `FlowLayout` for wrapping chips
- Context menus, swipe-to-delete, adaptive grids

### 4. Navigation

Tab-based root with `NavigationStack` per tab, `navigationDestination`
for detail pushes, and sheets for modal flows.

---

## Verifying data persistence

1. Open **Portfolio** → **Set up my portfolio**.
2. Add a position — pick a ticker, enter shares and the price paid.
3. **Force-quit** the app (swipe up from the app switcher — not just
   backgrounding it).
4. Reopen. The holding is still there, priced against live data.

The same applies to the watchlist (star any stock) and to pinned index
cards on the Markets screen.

---

## Notes on data sources

- Finnhub's free tier does not include the candle endpoint (returns HTTP
  403), so historical chart data comes from Yahoo Finance instead.
- "Top Movers" is ranked client-side across a fixed set of large-cap
  symbols, because the free tier has no gainers/losers endpoint. The UI
  states this explicitly rather than implying whole-market coverage.
- The DCA simulator projects from an assumed return rate that the user
  controls. It is not a backtest, and the screen says so.
- AI output is labelled as AI-generated and is not financial advice. All
  portfolio figures — weights, returns, concentration index — are computed
  in Swift; the model only interprets them.

## Known limitation

API keys are committed in source. Acceptable for coursework review, but a
production app would load them from a secure store rather than the bundle.
