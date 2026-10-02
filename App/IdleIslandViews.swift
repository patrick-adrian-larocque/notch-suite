import NotchCore
import SwiftUI

/// The open idle island, "Home": the date and time, a collapse button, and shortcuts.
///
/// Laid out as on the canvas at 440 × 156: content starts 40 pt down, below the menu
/// bar, with 20 pt sides and 16 pt at the bottom. The canvas's calendar chip is left out
/// (#35). Compact and peek idle are an empty black pill, so they have no view.
struct IdleOpenView: View {
    let palette: IslandPalette
    let collapse: () -> Void
    /// Starts a timer, or `nil` until the timer ships (#36).
    var startTimer: (() -> Void)?
    /// Opens the file shelf, or `nil` until the shelf view ships.
    var openShelf: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                clock
                Spacer(minLength: 0)
                CollapseButton(palette: palette, action: collapse)
            }
            .frame(height: IslandSize.minimumHitTarget)

            HStack(spacing: 10) {
                PillButton(
                    title: "Start timer", systemImage: "timer", palette: palette,
                    action: startTimer)
                PillButton(
                    title: "Open shelf", systemImage: "folder", palette: palette,
                    action: openShelf)
            }
        }
        .padding(EdgeInsets(top: 40, leading: 20, bottom: 16, trailing: 20))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var clock: some View {
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 1) {
                Text(context.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(IslandFont.caption)
                    .foregroundStyle(palette.secondary)
                Text(
                    context.date,
                    format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute()
                )
                .font(IslandFont.clock)
                .foregroundStyle(palette.primary)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
