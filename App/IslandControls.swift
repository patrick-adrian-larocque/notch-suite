import NotchCore
import SwiftUI

/// The island's two kinds of button, as on the canvas: a filled pill and a round
/// icon-only "ghost" that only shows a fill under the pointer.
///
/// Both are at least 44 × 44 pt, the minimum hit target.
struct IslandButtonStyle: ButtonStyle {
    enum Kind {
        /// A wide button with a filled, rounded background, such as "Open shelf".
        case pill
        /// A round icon button with no fill until hovered or pressed, such as collapse.
        case icon
    }

    let kind: Kind
    let palette: IslandPalette

    func makeBody(configuration: Configuration) -> some View {
        IslandButton(configuration: configuration, kind: kind, palette: palette)
    }
}

private struct IslandButton: View {
    let configuration: ButtonStyleConfiguration
    let kind: IslandButtonStyle.Kind
    let palette: IslandPalette

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let isActive = isEnabled && (isHovered || configuration.isPressed)
        let side = IslandSize.minimumHitTarget
        configuration.label
            .frame(
                minWidth: side, maxWidth: kind == .pill ? .infinity : side,
                minHeight: side, maxHeight: side
            )
            .background { background(isActive: isActive) }
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private func background(isActive: Bool) -> some View {
        switch kind {
        case .pill:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isActive ? palette.controlFillActive : palette.controlFill)
        case .icon:
            Circle().fill(isActive ? palette.controlFillActive : .clear)
        }
    }
}

/// The round chevron button that returns an open island to compact.
struct CollapseButton: View {
    let palette: IslandPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.icon)
        }
        .buttonStyle(IslandButtonStyle(kind: .icon, palette: palette))
        .accessibilityLabel("Collapse")
        .help("Collapse")
    }
}

/// A pill button with an icon and a title.
///
/// A `nil` action shows the button disabled, for features that haven't shipped yet.
struct PillButton: View {
    let title: String
    let systemImage: String
    let palette: IslandPalette
    let action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .accessibilityHidden(true)
                Text(title)
            }
            .font(IslandFont.control)
            .foregroundStyle(palette.primary)
        }
        .buttonStyle(IslandButtonStyle(kind: .pill, palette: palette))
        .disabled(action == nil)
        .accessibilityHint(action == nil ? "Not available yet" : "")
    }
}
