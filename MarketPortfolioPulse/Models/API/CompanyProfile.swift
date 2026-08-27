import Foundation

/// GET /stock/profile2
/// Finnhub returns an empty object for symbols without a company profile
/// (e.g. ETFs like VOO/QQQ/SPY), so all fields must be optional.
struct CompanyProfile: Codable {
    let name: String?
    let ticker: String?
    let logo: String?
    let weburl: String?
    let finnhubIndustry: String?
    let marketCapitalization: Double?
    let shareOutstanding: Double?
}
