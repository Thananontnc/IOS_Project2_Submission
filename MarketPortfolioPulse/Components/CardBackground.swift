import SwiftUI

struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = 16
    var tint: Color? = nil

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(.secondarySystemBackground))
                    if let tint {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(tint.opacity(0.08))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func cardBackground(cornerRadius: CGFloat = 16, tint: Color? = nil) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius, tint: tint))
    }
}

struct SkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12

    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2.5)
            .fill(Color.secondary.opacity(pulse ? 0.12 : 0.22))
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

/// Small round avatar showing a ticker's initials — a stand-in for a real
/// logo image, giving list rows a bit of visual anchor.
struct TickerAvatar: View {
    let symbol: String
    var diameter: CGFloat = 36

    private var initials: String {
        String(symbol.prefix(2))
    }

    private var tint: Color {
        let hash = symbol.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let palette: [Color] = [.blue, .purple, .orange, .teal, .pink, .indigo]
        return palette[hash % palette.count]
    }

    var body: some View {
        // Same squircle as StockLogoView so a fallback avatar and a real
        // logo sit interchangeably in a list without the shape changing.
        RoundedRectangle(cornerRadius: diameter * 0.26, style: .continuous)
            .fill(tint.opacity(0.18))
            .overlay(
                Text(initials)
                    .font(.system(size: diameter * 0.36, weight: .bold))
                    .foregroundStyle(tint)
            )
            .frame(width: diameter, height: diameter)
    }
}
