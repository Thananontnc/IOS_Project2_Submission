import SwiftUI

/// Non-blocking inline error banner with a retry action.
struct ErrorBanner: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.subheadline)
                Button("Retry", action: retryAction)
                    .font(.subheadline.bold())
            }
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    ErrorBanner(message: "Rate limit exceeded. Please try again shortly.") {}
        .padding()
}
