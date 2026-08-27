import SwiftUI

/// User-facing appearance choice.
///
/// `.system` maps to a nil `preferredColorScheme`, which lets iOS keep
/// following the device setting (including automatic day/night switching)
/// rather than pinning the app to whatever the device was on at launch.
enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "iphone"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// Segmented theme picker, used in the settings sheet.
struct ThemePicker: View {
    @Binding var selection: AppTheme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppTheme.allCases) { theme in
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selection = theme }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: theme.systemImage)
                            .font(.title3)
                        Text(theme.label)
                            .font(.caption.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selection == theme
                                  ? Color.accentColor.opacity(0.15)
                                  : Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                selection == theme ? Color.accentColor : Color.clear,
                                lineWidth: 1.5
                            )
                    )
                    .foregroundStyle(selection == theme ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    @Previewable @State var theme = AppTheme.system
    return ThemePicker(selection: $theme).padding()
}
