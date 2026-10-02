import SwiftUI

/// The island's outline: a rectangle hanging from the top edge, square at the top where
/// it meets the bezel and rounded at the bottom.
///
/// It is drawn centred at the top of whatever rect it fills, so the window can stay one
/// fixed size while the island grows and shrinks inside it. Width, height and corner
/// radius animate together through `animatableData`, so one spring drives the whole
/// morph instead of three animations drifting apart. The canvas shows no outward "ears"
/// at the top corners, so there are none here.
struct NotchShape: Shape {
    var islandWidth: CGFloat
    var islandHeight: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(islandWidth, AnimatablePair(islandHeight, bottomRadius)) }
        set {
            islandWidth = newValue.first
            islandHeight = newValue.second.first
            bottomRadius = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        // A spring overshoots, so clamp anything that would turn the path inside out.
        let width = min(max(islandWidth, 0), rect.width)
        let height = min(max(islandHeight, 0), rect.height)
        let radius = min(max(bottomRadius, 0), width / 2, height)
        let island = CGRect(x: rect.midX - width / 2, y: rect.minY, width: width, height: height)
        return UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius,
            topTrailingRadius: 0,
            style: .continuous
        )
        .path(in: island)
    }
}
