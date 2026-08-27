import SwiftUI

/// Caps content width on wide screens (iPad, landscape) and centers it,
/// while staying completely untouched on iPhone-compact screens.
///
/// Uses `@Environment(\.horizontalSizeClass)` rather than a measured
/// width (GeometryReader/PreferenceKey or `containerRelativeFrame`, both
/// tried first). Those measurement-based approaches need an async update
/// to correct an initial guess, and greedy children (`LazyVGrid`, a
/// paging `TabView`) expand to fill whatever cap they're given the
/// instant it's wider than the true screen — so any stale, not-yet-updated
/// measurement leaves content permanently oversized, centered, and
/// cropped on both edges. Gating on size class instead means the cap is
/// only ever applied on `.regular` width devices, where the real screen
/// is already at least as wide as typical cap values — so there's no
/// window where a greedy child sees an invitation to overshoot a narrow
/// phone screen. On `.compact` (all iPhones in portrait, most in
/// landscape) the modifier does nothing at all.
private struct ResponsiveContainer: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    func responsiveContainer(maxWidth: CGFloat = 680) -> some View {
        modifier(ResponsiveContainer(maxWidth: maxWidth))
    }
}

/// Adaptive grid columns: 1 column on iPhone-width screens, 2+ once there's
/// room, used for card grids (Top Movers, News, Holdings) so they reflow
/// instead of stretching a single column edge-to-edge on iPad.
enum AdaptiveGrid {
    static func columns(minWidth: CGFloat = 320, spacing: CGFloat = 12) -> [GridItem] {
        [GridItem(.adaptive(minimum: minWidth), spacing: spacing)]
    }
}
