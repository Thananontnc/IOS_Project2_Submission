import Foundation

enum TyphoonError: LocalizedError {
    case badURL
    case serverError(Int, String?)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Invalid AI request URL."
        case .serverError(let code, let body):
            if let body, !body.isEmpty {
                return "AI service error (\(code)): \(body)"
            }
            return "AI service returned an error (\(code))."
        case .emptyResponse:
            return "The AI returned an empty response."
        }
    }
}

// MARK: - Wire format (OpenAI-compatible)

private struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }
    struct ResponseFormat: Encodable {
        let type: String
    }
    let model: String
    let messages: [Message]
    let temperature: Double
    let max_tokens: Int
    let response_format: ResponseFormat?
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message?
    }
    let choices: [Choice]
}

/// Thin client over Typhoon's OpenAI-compatible chat completions endpoint.
actor TyphoonService {
    static let shared = TyphoonService()
    private init() {}

    /// Sends a single system+user turn and returns the assistant's text.
    func complete(
        system: String,
        user: String,
        temperature: Double = 0.3,
        maxTokens: Int = 700,
        jsonMode: Bool = false
    ) async throws -> String {
        guard let url = URL(string: "\(TyphoonAPI.baseURL)/chat/completions") else {
            throw TyphoonError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(TyphoonAPI.key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(
                model: TyphoonAPI.model,
                messages: [
                    .init(role: "system", content: system),
                    .init(role: "user", content: user)
                ],
                temperature: temperature,
                max_tokens: maxTokens,
                response_format: jsonMode ? .init(type: "json_object") : nil
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TyphoonError.serverError(-1, nil)
        }
        guard http.statusCode == 200 else {
            throw TyphoonError.serverError(http.statusCode, String(data: data, encoding: .utf8))
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        let text = decoded.choices.first?.message?.content?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { throw TyphoonError.emptyResponse }
        return text
    }

    /// Decodes a JSON reply, tolerating a markdown fence or stray prose
    /// around the object — models drift into both even in JSON mode.
    private func decodeJSON<T: Decodable>(_ type: T.Type, from raw: String) throws -> T {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = text.firstIndex(of: "{"), let end = Self.matchingBraceIndex(in: text, from: start) {
            text = String(text[start...end])
        }
        guard let data = text.data(using: .utf8) else { throw TyphoonError.emptyResponse }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Finds the `}` that closes the `{` at `start`, tracking nesting depth
    /// and skipping braces inside string literals so trailing prose after
    /// the object (which may itself contain `}`) doesn't get included.
    private static func matchingBraceIndex(in text: String, from start: String.Index) -> String.Index? {
        var depth = 0
        var inString = false
        var escaped = false
        var index = start
        while index < text.endIndex {
            let char = text[index]
            if inString {
                if escaped {
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else if char == "\"" {
                    inString = false
                }
            } else if char == "\"" {
                inString = true
            } else if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 { return index }
            }
            index = text.index(after: index)
        }
        return nil
    }

    /// Structured analysis of the headline feed, aware of the symbols the
    /// user actually follows.
    func analyzeNews(
        _ items: [MarketNews],
        watching symbols: [String] = [],
        limit: Int = 18
    ) async throws -> NewsAnalysis {
        let headlines = items.prefix(limit).enumerated().map { index, item in
            "\(index + 1). [\(item.source)] \(item.headline)"
        }.joined(separator: "\n")

        let watchLine = symbols.isEmpty
            ? "The user follows no specific symbols."
            : "The user follows: \(symbols.joined(separator: ", "))."

        let raw = try await complete(
            system: """
            You are a financial news analyst. Reply with ONLY a JSON \
            object and no markdown fence.

            Schema:
            {"sentiment":"bullish|bearish|mixed",
             "score":<integer -100 to 100>,
             "headline":"<max 12 words, the single biggest takeaway>",
             "themes":[{"title":"<max 5 words>",
                        "detail":"<max 25 words>",
                        "tickers":["TICKER"]}],
             "watchlistNote":"<max 35 words, or empty string>"}

            Give 3 to 4 themes. "tickers" lists only symbols clearly \
            implicated by the headlines; use [] when none. "score" is \
            negative for bearish, positive for bullish. "watchlistNote" \
            says what these headlines mean for the symbols the user \
            follows, or "" if they are unaffected.

            Report only what the headlines support. Never give investment \
            advice, recommendations, or price targets.
            """,
            user: "\(watchLine)\n\nHeadlines:\n\(headlines)",
            temperature: 0.2,
            maxTokens: 900,
            jsonMode: true
        )
        return try decodeJSON(NewsAnalysis.self, from: raw)
    }

    /// Interprets pre-computed portfolio metrics as a risk read.
    ///
    /// Every number in `metrics` is calculated in Swift. The model is asked
    /// to interpret them, never to compute — arithmetic from a language
    /// model has no place in a screen about someone's money.
    func analyzePortfolioRisk(_ metrics: PortfolioMetrics) async throws -> PortfolioRisk {
        let positionLines = metrics.positions
            .sorted { $0.weightPercent > $1.weightPercent }
            .map {
                String(
                    format: "- %@ (%@): %.1f%% of portfolio, return %.1f%%",
                    $0.ticker, $0.name, $0.weightPercent, $0.returnPercent
                )
            }
            .joined(separator: "\n")

        let raw = try await complete(
            system: """
            You are a portfolio risk analyst. Reply with ONLY a JSON \
            object and no markdown fence.

            Schema:
            {"level":"low|moderate|high",
             "score":<integer 0 to 100, higher means riskier>,
             "headline":"<max 14 words>",
             "concerns":[{"title":"<max 5 words>","detail":"<max 30 words>"}],
             "diversificationNote":"<max 35 words, or empty string>"}

            Give 2 to 4 concerns, most important first. Judge \
            concentration, sector overlap, position count and drawdown \
            exposure. A concentration index above 2500 is concentrated; \
            below 1500 is well spread.

            All figures are given to you — never invent or recalculate \
            numbers. Describe risk only. Do not tell the user to buy, \
            sell, or rebalance, and name no specific products.
            """,
            user: """
            Portfolio value: \(String(format: "%.0f", metrics.totalValue)) USD
            Cost basis: \(String(format: "%.0f", metrics.totalCost)) USD
            Total return: \(String(format: "%.1f", metrics.totalReturnPercent))%
            Positions: \(metrics.positionCount)
            Largest position: \(metrics.largestTicker) at \(String(format: "%.1f", metrics.largestWeightPercent))%
            Concentration index (HHI, 0-10000): \(String(format: "%.0f", metrics.concentrationIndex))

            Holdings:
            \(positionLines)
            """,
            temperature: 0.2,
            maxTokens: 900,
            jsonMode: true
        )
        return try decodeJSON(PortfolioRisk.self, from: raw)
    }

    /// Explains a DCA projection in plain language, with its caveats.
    func explainDCA(
        symbol: String,
        monthlyAmount: Double,
        years: Int,
        annualReturn: Double,
        totalInvested: Double,
        projectedValue: Double
    ) async throws -> String {
        return try await complete(
            system: """
            You explain investing concepts to beginners in plain, friendly \
            language. Be balanced and never promise returns. Under 120 \
            words. Plain text only, no markdown headers.
            """,
            user: """
            Explain this dollar-cost-averaging projection:
            Ticker: \(symbol)
            Invested \(String(format: "%.0f", monthlyAmount)) USD every month for \(years) years.
            Assumed average annual return: \(String(format: "%.1f", annualReturn))%.
            Total contributed: \(String(format: "%.0f", totalInvested)) USD.
            Projected final value: \(String(format: "%.0f", projectedValue)) USD.

            Cover: what DCA is, what this projection does and does not \
            account for, and that the assumed return is an input rather \
            than a prediction.
            """
        )
    }
}
