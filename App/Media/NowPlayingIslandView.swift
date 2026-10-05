import NotchCore
import SwiftUI

/// The Now Playing content for each island level.
///
/// Sizes come from `IslandLayout` (`.nowPlaying`): compact and peek wrap the notch, so
/// their content sits in the wings on each side and the middle stays clear for the
/// camera; open is a full player below the menu bar.
struct NowPlayingIslandView: View {
    let presentation: NowPlayingPresentation
    let level: IslandLevel
    let size: IslandSize
    let notchWidth: Double
    let palette: IslandPalette
    let motion: MotionSpec
    let collapse: () -> Void

    var body: some View {
        switch level {
        case .compact: compact
        case .peek: peek
        case .open: open
        }
    }

    // MARK: Compact and peek

    /// Artwork in the left wing, level bars in the right.
    private var compact: some View {
        wings {
            ArtworkView(presentation: presentation, side: 22, cornerRadius: 6, palette: palette)
        } trailing: {
            LevelBars(isPlaying: presentation.playback.isPlaying, motion: motion, palette: palette)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(compactLabel)
    }

    /// Artwork and title in the left wing, level bars in the right.
    private var peek: some View {
        wings {
            HStack(spacing: 8) {
                ArtworkView(
                    presentation: presentation, side: 26, cornerRadius: 7, palette: palette)
                Text(presentation.nowPlaying?.title ?? "")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        } trailing: {
            LevelBars(isPlaying: presentation.playback.isPlaying, motion: motion, palette: palette)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(compactLabel)
    }

    /// Lays out `leading` and `trailing` in the wings beside the notch.
    private func wings<Leading: View, Trailing: View>(
        @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        let wing = max(0, (size.width - notchWidth) / 2)
        let inset = 10.0
        return HStack(spacing: 0) {
            leading()
                .frame(width: max(0, wing - inset * 1.5), alignment: .leading)
                .padding(.leading, inset)
            Spacer(minLength: notchWidth)
            trailing()
                .frame(width: max(0, wing - inset * 1.5), alignment: .trailing)
                .padding(.trailing, inset)
        }
        .frame(width: size.width, height: size.height)
    }

    private var compactLabel: String {
        guard let track = presentation.nowPlaying else { return "Nothing playing" }
        let state = presentation.playback.isPlaying ? "Playing" : "Paused"
        return [state, track.title, track.artist].compactMap { $0 }.joined(separator: ", ")
    }

    // MARK: Open

    private var open: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                ArtworkView(
                    presentation: presentation, side: 64, cornerRadius: 12, palette: palette)
                VStack(alignment: .leading, spacing: 3) {
                    Text(presentation.nowPlaying?.title ?? "Nothing playing")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(IslandFont.caption)
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                    AppBadge(presentation: presentation, palette: palette)
                }
                .truncationMode(.tail)
                Spacer(minLength: 0)
                CollapseButton(palette: palette, action: collapse)
            }
            ProgressRow(presentation: presentation, palette: palette)
            TransportControls(presentation: presentation, palette: palette)
        }
        .padding(EdgeInsets(top: 40, leading: 20, bottom: 14, trailing: 20))
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    private var subtitle: String {
        if presentation.isEngineDown { return "Now Playing is unavailable" }
        guard let track = presentation.nowPlaying else { return "" }
        let parts = [track.artist, track.album].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.joined(separator: " — ")
    }
}

// MARK: - Pieces

/// The track's artwork, a shimmer while it loads, or a placeholder note.
private struct ArtworkView: View {
    let presentation: NowPlayingPresentation
    let side: Double
    let cornerRadius: Double
    let palette: IslandPalette

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            if let image = presentation.artworkImage {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else if presentation.artwork == .loading {
                shape.fill(palette.controlFill).overlay { Shimmer() }
            } else {
                shape.fill(palette.controlFill)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: side * 0.45, weight: .medium))
                            .foregroundStyle(palette.secondary)
                    }
            }
        }
        .frame(width: side, height: side)
        .clipShape(shape)
        .accessibilityHidden(true)
    }
}

/// A soft band sweeping across, for artwork that hasn't arrived yet.
private struct Shimmer: View {
    @State private var phase = -1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LinearGradient(
            colors: [.clear, .white.opacity(0.18), .clear], startPoint: .leading,
            endPoint: .trailing
        )
        .offset(x: reduceMotion ? 0 : phase * 60)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

/// Three bars that bounce while playing and rest flat when paused or under reduce motion.
private struct LevelBars: View {
    let isPlaying: Bool
    let motion: MotionSpec
    let palette: IslandPalette

    var body: some View {
        let animates = isPlaying && !motion.reducesMotion
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !animates)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(palette.accent)
                        .frame(width: 3, height: height(index: index, time: t, animates: animates))
                }
            }
            .frame(height: 14)
        }
        .accessibilityHidden(true)
    }

    private func height(index: Int, time: Double, animates: Bool) -> Double {
        guard animates else { return isPlaying ? 8 : 4 }
        let speeds = [5.1, 6.7, 4.3]
        let wave = (sin(time * speeds[index] + Double(index)) + 1) / 2
        return 4 + wave * 10
    }
}

/// The player's icon and name, such as Safari for a YouTube tab.
private struct AppBadge: View {
    let presentation: NowPlayingPresentation
    let palette: IslandPalette

    var body: some View {
        if let app = presentation.app, let name = app.displayName {
            HStack(spacing: 5) {
                if let icon = app.icon {
                    Image(nsImage: icon).resizable().frame(width: 14, height: 14)
                }
                Text(name).font(.system(size: 11)).foregroundStyle(palette.secondary)
            }
            .padding(.top, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Playing in \(name)")
        }
    }
}

/// Elapsed time, a progress bar, and remaining time, ticking once a second.
private struct ProgressRow: View {
    let presentation: NowPlayingPresentation
    let palette: IslandPalette

    var body: some View {
        let progress = presentation.progress
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            HStack(spacing: 10) {
                Text(progress?.elapsedText(at: now) ?? "0:00")
                    .frame(width: 44, alignment: .leading)
                GeometryReader { proxy in
                    let fraction = progress?.fraction(at: now) ?? 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(palette.controlFill)
                        Capsule().fill(palette.primary.opacity(0.85))
                            .frame(width: proxy.size.width * fraction)
                    }
                }
                .frame(height: 4)
                Text(progress?.remainingText(at: now) ?? "")
                    .frame(width: 44, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(palette.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText(progress: progress, now: now))
        }
    }

    private func accessibilityText(progress: PlaybackProgress?, now: Date) -> String {
        guard let progress else { return "No progress" }
        let elapsed = progress.elapsedText(at: now)
        guard let duration = progress.duration else { return "\(elapsed) elapsed" }
        return "\(elapsed) of \(PlaybackTimeFormat.elapsed(duration))"
    }
}

/// Previous, play or pause, and next.
private struct TransportControls: View {
    let presentation: NowPlayingPresentation
    let palette: IslandPalette

    var body: some View {
        let isPlaying = presentation.playback.isPlaying
        let hasTrack = presentation.nowPlaying != nil
        HStack(spacing: 28) {
            control("backward.fill", label: "Previous", action: presentation.previousTrack)
            control(
                isPlaying ? "pause.fill" : "play.fill", label: isPlaying ? "Pause" : "Play",
                size: 22, action: presentation.togglePlayPause)
            control("forward.fill", label: "Next", action: presentation.nextTrack)
        }
        .frame(maxWidth: .infinity)
        .disabled(!hasTrack || presentation.isEngineDown)
    }

    private func control(
        _ symbol: String, label: String, size: Double = 17, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(palette.primary)
        }
        .buttonStyle(IslandButtonStyle(kind: .icon, palette: palette))
        .accessibilityLabel(label)
        .help(label)
    }
}

// MARK: - Previews

#if DEBUG
    extension IslandPalette {
        fileprivate static let preview = IslandPalette(
            appearance: IslandAppearance(hasNotch: true, system: .dark, accent: .blue))
    }

    extension MotionSpec {
        fileprivate static let preview = MotionSpec(settings: .defaults, systemReduceMotion: false)
    }

    /// Wraps content in the island's own black canvas, the way the real panel shows it.
    private func previewCanvas(
        level: IslandLevel, size: IslandSize, @ViewBuilder content: () -> some View
    )
        -> some View
    {
        content()
            .frame(width: size.width, height: size.height)
            .background(level == .open ? Color.black : Color.black.opacity(0.001))
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
            .padding(20)
            .background(Color(white: 0.15))
    }

    #Preview("Compact") {
        let size = IslandLayout.design.size(for: .nowPlaying, at: .compact)
        previewCanvas(level: .compact, size: size) {
            NowPlayingIslandView(
                presentation: .preview(title: "Midnight City", artist: "M83"), level: .compact,
                size: size, notchWidth: IslandLayout.designNotchWidth, palette: .preview,
                motion: .preview, collapse: {})
        }
    }

    #Preview("Peek") {
        let size = IslandLayout.design.size(for: .nowPlaying, at: .peek)
        previewCanvas(level: .peek, size: size) {
            NowPlayingIslandView(
                presentation: .preview(
                    title: "A Long Enough Title That It Has To Truncate Somewhere", artist: "M83"),
                level: .peek, size: size, notchWidth: IslandLayout.designNotchWidth,
                palette: .preview, motion: .preview, collapse: {})
        }
    }

    #Preview("Open") {
        let size = IslandLayout.design.size(for: .nowPlaying, at: .open)
        previewCanvas(level: .open, size: size) {
            NowPlayingIslandView(
                presentation: .preview(
                    title: "Midnight City", artist: "M83", album: "Hurry Up, We're Dreaming"),
                level: .open, size: size, notchWidth: IslandLayout.designNotchWidth,
                palette: .preview, motion: .preview, collapse: {})
        }
    }

    #Preview("Open, paused, artwork loading") {
        let size = IslandLayout.design.size(for: .nowPlaying, at: .open)
        previewCanvas(level: .open, size: size) {
            NowPlayingIslandView(
                presentation: .preview(
                    title: "Midnight City", artist: "M83", playing: false, artwork: .loading),
                level: .open, size: size, notchWidth: IslandLayout.designNotchWidth,
                palette: .preview, motion: .preview, collapse: {})
        }
    }

    #Preview("Open, engine down") {
        let size = IslandLayout.design.size(for: .nowPlaying, at: .open)
        previewCanvas(level: .open, size: size) {
            NowPlayingIslandView(
                presentation: .preview(title: "Midnight City", artist: "M83", isEngineDown: true),
                level: .open, size: size, notchWidth: IslandLayout.designNotchWidth,
                palette: .preview, motion: .preview, collapse: {})
        }
    }
#endif
