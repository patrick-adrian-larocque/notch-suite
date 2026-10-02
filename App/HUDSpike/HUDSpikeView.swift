// HUD spike (#26): Debug builds only.
#if DEBUG

    import AppKit
    import NotchCore
    import Observation
    import SwiftUI

    /// The levels the spike HUD draws. The HUD's timing comes from `IslandStateMachine`.
    @MainActor
    @Observable
    final class HUDSpikeModel {
        let machine: IslandStateMachine
        var volume = 0.0
        var isMuted = false
        var brightness = 0.0
        var keyboard = 0.0

        init(machine: IslandStateMachine) {
            self.machine = machine
        }

        func level(for kind: SystemHUDKind) -> Double {
            switch kind {
            case .volume: volume
            case .brightness: brightness
            case .keyboardBrightness: keyboard
            }
        }
    }

    /// The prototype HUD from the canvas "System HUDs" board: a 440 × 40 peek island with an
    /// icon, a label and 12 level segments.
    struct HUDSpikeView: View {
        static let size = CGSize(width: 440, height: 40)
        static let segmentCount = 12

        let model: HUDSpikeModel
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            ZStack(alignment: .top) {
                if let kind = model.machine.hud {
                    content(for: kind)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
            }
            .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
            // MotionSpec.hudMorph: cubic-bezier(.34, 1.4, .64, 1) over 0.45 s.
            .animation(
                reduceMotion ? nil : .timingCurve(0.34, 1.4, 0.64, 1, duration: 0.45),
                value: model.machine.hud)
        }

        private func content(for kind: SystemHUDKind) -> some View {
            let state = HUDSpikeState(kind: kind, model: model)
            return HStack {
                HStack(spacing: 8) {
                    Image(systemName: state.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 18, height: 18)
                        .foregroundStyle(state.isSilent ? hudSpikeColor(0xA1A1AA) : .white)
                    Text(state.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                }
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<Self.segmentCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(state.color(forSegment: index))
                            .frame(width: 7, height: 12)
                    }
                }
                .animation(.easeOut(duration: 0.12), value: state.litSegments)
            }
            .padding(.horizontal, 14)
            .frame(width: Self.size.width, height: Self.size.height)
            .background(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: 14, bottomTrailingRadius: 14, style: .continuous
                )
                .fill(.black)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.accessibilityLabel)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    /// What one HUD frame shows, worked out from the kind and the model's levels.
    @MainActor
    struct HUDSpikeState {
        var kind: SystemHUDKind
        var level: Double
        var isMuted: Bool

        init(kind: SystemHUDKind, model: HUDSpikeModel) {
            self.kind = kind
            level = model.level(for: kind)
            isMuted = kind == .volume && model.isMuted
        }

        var litSegments: Int {
            Int((min(max(level, 0), 1) * Double(HUDSpikeView.segmentCount)).rounded())
        }

        /// Volume that is muted or at zero: the icon and lit segments turn grey.
        var isSilent: Bool { kind == .volume && (isMuted || litSegments == 0) }

        var label: String {
            switch kind {
            case .volume: isMuted ? "Muted" : "Volume"
            case .brightness: "Brightness"
            case .keyboardBrightness: "Keyboard"
            }
        }

        /// The canvas uses its own stroke icons; SF Symbols stand in for them here.
        var symbol: String {
            switch kind {
            case .volume:
                if isSilent { return "speaker.slash" }
                switch litSegments {
                case ...4: return "speaker.wave.1"
                case ...8: return "speaker.wave.2"
                default: return "speaker.wave.3"
                }
            case .brightness: return "sun.max"
            case .keyboardBrightness: return "light.max"
            }
        }

        var accessibilityLabel: String {
            let name =
                switch kind {
                case .volume: "Volume"
                case .brightness: "Brightness"
                case .keyboardBrightness: "Keyboard brightness"
                }
            // Only real mute says "muted"; a quiet level still reads its percentage.
            if isMuted { return "\(name) muted" }
            return "\(name) \(Int((level * 100).rounded())) percent"
        }

        func color(forSegment index: Int) -> Color {
            guard index < litSegments else { return hudSpikeColor(0x3F3F46) }
            return isSilent ? hudSpikeColor(0x71717A) : .white
        }
    }

    /// A colour from a `0xRRGGBB` value, as the canvas writes them.
    private func hudSpikeColor(_ hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }

#endif
