import Foundation

/// GET /quote
struct StockQuote: Codable, Equatable {
    let c: Double   // current price
    let d: Double   // change
    let dp: Double  // change percent
    let h: Double   // high
    let l: Double   // low
    let o: Double   // open
    let pc: Double  // previous close
}
