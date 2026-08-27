import Foundation

/// GET /stock/candle
/// Finnhub omits the array fields entirely when `s == "no_data"`, so they
/// must be optional to decode successfully in that case.
struct CandleData: Codable {
    let c: [Double]?  // close
    let h: [Double]?  // high
    let l: [Double]?  // low
    let o: [Double]?  // open
    let t: [Int]?     // timestamp (unix seconds)
    let v: [Double]?  // volume
    let s: String      // status: "ok" or "no_data"

    var closes: [Double] { c ?? [] }
    var highs: [Double] { h ?? [] }
    var lows: [Double] { l ?? [] }
    var opens: [Double] { o ?? [] }
    var timestamps: [Int] { t ?? [] }
    var volumes: [Double] { v ?? [] }

    var hasData: Bool { s == "ok" && !closes.isEmpty }
}
