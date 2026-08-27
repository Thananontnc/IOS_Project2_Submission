import Foundation

/// Rolling-window rate limiter.
///
/// Finnhub's free tier allows ~60 calls/minute. The dashboard quotes ~22
/// symbols per refresh, so an unthrottled refresh loop plus pull-to-refresh
/// blows through that quickly and the API starts returning 429s. Every
/// request funnels through here: it permits bursts up to the budget (so a
/// cold start stays fast) and then paces callers, waiting only as long as
/// it takes for the oldest request to age out of the window.
actor RateLimiter {
    private let limit: Int
    private let window: TimeInterval
    /// Minimum gap between two grants. The per-minute budget alone isn't
    /// enough: firing ~22 quote requests in the same instant trips a burst
    /// limit and comes back 429 even while the minute budget is untouched.
    /// Spacing them keeps a full refresh well under a couple of seconds.
    private let minimumSpacing: TimeInterval
    private var timestamps: [Date] = []
    private var lastGrant: Date?

    init(limit: Int, window: TimeInterval = 60, minimumSpacing: TimeInterval = 0.25) {
        self.limit = limit
        self.window = window
        self.minimumSpacing = minimumSpacing
    }

    /// Server-reported budget, when the API sends it. Trusted over the
    /// local rolling count: the local one resets each app launch while the
    /// server's window does not, so relaunching used to walk straight into
    /// a 429 with a "full" local budget.
    private var serverRemaining: Int?
    private var serverResetAt: Date?

    func syncBudget(remaining: Int?, resetAt: Date?) {
        if let remaining { serverRemaining = remaining }
        if let resetAt { serverResetAt = resetAt }
    }

    /// Seconds until the server's window rolls over, floored at 0.
    func secondsUntilReset() -> TimeInterval {
        guard let serverResetAt else { return 0 }
        return max(serverResetAt.timeIntervalSinceNow, 0)
    }

    func acquire() async {
        // Server says budget spent — wait for the exact reset instant
        // instead of guessing.
        if let remaining = serverRemaining, remaining <= 0 {
            let wait = secondsUntilReset()
            if wait > 0, wait < window * 2 {
                try? await Task.sleep(nanoseconds: UInt64((wait + 0.2) * 1_000_000_000))
            }
            serverRemaining = nil
            timestamps.removeAll()
        }

        while true {
            // Hold the floor between consecutive grants first.
            if let lastGrant {
                let since = Date().timeIntervalSince(lastGrant)
                if since < minimumSpacing {
                    let wait = minimumSpacing - since
                    try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                    if Task.isCancelled { return }
                }
            }

            let now = Date()
            timestamps.removeAll { now.timeIntervalSince($0) >= window }

            if timestamps.count < limit {
                timestamps.append(now)
                lastGrant = now
                return
            }

            // Wait until the oldest call leaves the window, plus a small
            // margin so we don't spin on the boundary.
            guard let oldest = timestamps.first else { continue }
            let wait = window - now.timeIntervalSince(oldest) + 0.05
            if wait > 0 {
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
            if Task.isCancelled { return }
        }
    }
}
