import SwiftUI

/// A plain black island that hugs the top edge of the screen.
///
/// Square at the top, where it meets the bezel, and rounded at the bottom. It stands in
/// for the real island views until they exist.
struct IslandPlaceholderView: View {
    var cornerRadius: Double

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: 0,
            style: .continuous
        )
        .fill(.black)
    }
}
