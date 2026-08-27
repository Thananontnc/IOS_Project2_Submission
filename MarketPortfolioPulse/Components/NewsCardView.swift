import SwiftUI

/// Lead story: large image, headline, and the API's `summary` — which the
/// feed always returns but the old layout never displayed.
struct FeaturedNewsCard: View {
    let news: MarketNews

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if news.hasRealImage {
                AsyncImage(url: URL(string: news.image)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Rectangle().fill(Color.secondary.opacity(0.12))
                    }
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipped()
            } else {
                // No photo from this publisher — a tinted band keyed to the
                // source reads better than a cropped wordmark.
                SourceBanner(source: news.source)
                    .frame(height: 76)
                    .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 6) {
                NewsMetaRow(news: news)

                Text(news.headline)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                if !news.summary.isEmpty {
                    Text(news.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(14)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Source, "top news" flag, and relative age on one line.
struct NewsMetaRow: View {
    let news: MarketNews

    var body: some View {
        HStack(spacing: 6) {
            Text(news.source.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.accentColor)

            if news.isTopNews {
                Text("TOP")
                    .font(.system(size: 8, weight: .heavy))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.18))
                    .foregroundStyle(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            Text("·").foregroundStyle(.tertiary)

            Text(news.relativeAge)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
    }
}

/// Compact list row for everything after the lead story.
struct NewsCardView: View {
    let news: MarketNews

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            VStack(alignment: .leading, spacing: 4) {
                NewsMetaRow(news: news)

                Text(news.headline)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }

            Group {
                if news.hasRealImage {
                    AsyncImage(url: URL(string: news.image)) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Rectangle().fill(Color.secondary.opacity(0.12))
                        }
                    }
                } else {
                    SourceBanner(source: news.source, compact: true)
                }
            }
            .frame(width: 62, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
    }
}

/// Stand-in for publishers that supply no article photo. Deterministic
/// colour per source so Reuters rows stay visually consistent with each
/// other rather than looking like broken images.
struct SourceBanner: View {
    let source: String
    var compact = false

    private var tint: Color {
        let hash = source.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let palette: [Color] = [.blue, .indigo, .teal, .purple, .orange, .pink]
        return palette[hash % palette.count]
    }

    private var monogram: String {
        String(source.prefix(compact ? 2 : 3)).uppercased()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [tint.opacity(0.28), tint.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if compact {
                Text(monogram)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
            } else {
                HStack(spacing: 7) {
                    Image(systemName: "newspaper.fill")
                        .font(.subheadline)
                    Text(source.uppercased())
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(1.2)
                }
                .foregroundStyle(tint)
            }
        }
    }
}

#Preview {
    let sample = MarketNews(
        id: 1,
        headline: "Markets rally as tech earnings beat expectations across the board",
        summary: "Investors pushed indexes higher after several megacap results landed ahead of forecasts.",
        url: "https://example.com",
        image: "",
        datetime: Int(Date().timeIntervalSince1970) - 7200,
        source: "Reuters",
        category: "top news"
    )
    return ScrollView {
        VStack(spacing: 16) {
            FeaturedNewsCard(news: sample)
            NewsCardView(news: sample)
        }
        .padding()
    }
}
