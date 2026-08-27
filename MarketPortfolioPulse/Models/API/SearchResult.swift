import Foundation

/// GET /search — a single row of the `result` array.
struct SearchResult: Codable, Identifiable, Hashable {
    let symbol: String
    let displaySymbol: String
    let description: String
    let type: String

    var id: String { symbol }
}

/// GET /search — the full response wrapper: `{ "count": N, "result": [...] }`
struct SymbolLookupResponse: Codable {
    let count: Int
    let result: [SearchResult]
}
