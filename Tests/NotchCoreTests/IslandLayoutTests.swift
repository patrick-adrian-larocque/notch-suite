import Testing

@testable import NotchCore

@Suite struct IslandLayoutTests {
    /// Every size on the design canvas, at the design's 196 pt notch.
    static let canvas: [(IslandMode, IslandLevel, IslandSize)] = [
        (.idle, .compact, IslandSize(width: 196, height: 32, cornerRadius: 10)),
        (.idle, .peek, IslandSize(width: 232, height: 36, cornerRadius: 12)),
        (.idle, .open, IslandSize(width: 440, height: 156, cornerRadius: 30)),
        (.nowPlaying, .compact, IslandSize(width: 348, height: 36, cornerRadius: 12)),
        (.nowPlaying, .peek, IslandSize(width: 440, height: 40, cornerRadius: 14)),
        (.nowPlaying, .open, IslandSize(width: 460, height: 206, cornerRadius: 32)),
        (.timer, .compact, IslandSize(width: 320, height: 36, cornerRadius: 12)),
        (.timer, .peek, IslandSize(width: 400, height: 40, cornerRadius: 14)),
        (.timer, .open, IslandSize(width: 420, height: 168, cornerRadius: 30)),
        (.message, .compact, IslandSize(width: 300, height: 36, cornerRadius: 12)),
        (.message, .peek, IslandSize(width: 440, height: 40, cornerRadius: 14)),
        (.message, .open, IslandSize(width: 440, height: 104, cornerRadius: 28)),
        (.charging, .compact, IslandSize(width: 340, height: 36, cornerRadius: 12)),
        (.charging, .peek, IslandSize(width: 400, height: 40, cornerRadius: 14)),
        (.charging, .open, IslandSize(width: 400, height: 120, cornerRadius: 28)),
        (.shelf, .compact, IslandSize(width: 300, height: 36, cornerRadius: 12)),
        (.shelf, .peek, IslandSize(width: 380, height: 40, cornerRadius: 14)),
        (.shelf, .open, IslandSize(width: 460, height: 200, cornerRadius: 30)),
    ]

    @Test(arguments: canvas)
    func matchesCanvas(mode: IslandMode, level: IslandLevel, expected: IslandSize) {
        #expect(IslandLayout.design.size(for: mode, at: level) == expected)
    }

    @Test func canvasCoversEveryModeAndLevel() {
        let covered = Set(Self.canvas.map { "\($0.0.rawValue)/\($0.1.rawValue)" })
        let all = Set(
            IslandMode.allCases.flatMap { mode in
                IslandLevel.allCases.map { "\(mode.rawValue)/\($0.rawValue)" }
            })
        #expect(Self.canvas.count == 18)
        #expect(covered == all)
    }

    @Test func defaultNotchWidthIsTheDesigns() {
        #expect(IslandLayout().notchWidth == 196)
        #expect(IslandLayout.design == IslandLayout(notchWidth: IslandLayout.designNotchWidth))
    }

    /// The canvas's per-mode wings, as (compact, peek).
    static let wings: [(IslandMode, Double, Double)] = [
        (.idle, 0, 18),
        (.nowPlaying, 76, 122),
        (.timer, 62, 102),
        (.message, 52, 122),
        (.charging, 72, 102),
        (.shelf, 52, 92),
    ]

    @Test(arguments: wings)
    func wingsMatchCanvas(mode: IslandMode, compact: Double, peek: Double) {
        #expect(mode.compactWing == compact)
        #expect(mode.peekWing == peek)
    }

    /// The ends and middle of the canvas's notch-width preview slider.
    static let notchWidths: [Double] = [160, 196, 240]

    @Test(arguments: wings, notchWidths)
    func compactAndPeekWidthIsNotchPlusTwoWings(
        wing: (IslandMode, Double, Double), notchWidth: Double
    ) {
        let (mode, compactWing, peekWing) = wing
        let layout = IslandLayout(notchWidth: notchWidth)
        let compact = layout.size(for: mode, at: .compact)
        let peek = layout.size(for: mode, at: .peek)
        #expect(compact.width == notchWidth + 2 * compactWing)
        #expect(peek.width == notchWidth + 2 * peekWing)

        // Only the width follows the notch.
        let designCompact = IslandLayout.design.size(for: mode, at: .compact)
        let designPeek = IslandLayout.design.size(for: mode, at: .peek)
        #expect(compact.height == designCompact.height)
        #expect(compact.cornerRadius == designCompact.cornerRadius)
        #expect(peek.height == designPeek.height)
        #expect(peek.cornerRadius == designPeek.cornerRadius)
    }

    @Test(arguments: IslandMode.allCases, notchWidths)
    func openIsTheDesignSizeButNeverNarrowerThanPeek(mode: IslandMode, notchWidth: Double) {
        let layout = IslandLayout(notchWidth: notchWidth)
        let open = layout.size(for: mode, at: .open)
        let designOpen = IslandLayout.design.size(for: mode, at: .open)
        let peek = layout.size(for: mode, at: .peek)
        #expect(open.width == max(designOpen.width, peek.width))
        #expect(open.height == designOpen.height)
        #expect(open.cornerRadius == designOpen.cornerRadius)
    }

    @Test func openWidensOnAWideNotch() {
        let wide = IslandLayout(notchWidth: 240)
        #expect(wide.size(for: .nowPlaying, at: .open).width == 484)
        #expect(wide.size(for: .charging, at: .open).width == 444)
        #expect(IslandLayout(notchWidth: 160).size(for: .nowPlaying, at: .open).width == 460)
    }

    @Test(arguments: IslandMode.allCases, notchWidths)
    func eachLevelIsAtLeastAsLargeAsTheOneBelow(mode: IslandMode, notchWidth: Double) {
        let layout = IslandLayout(notchWidth: notchWidth)
        let sizes = IslandLevel.allCases.sorted().map { layout.size(for: mode, at: $0) }
        for (smaller, larger) in zip(sizes, sizes.dropFirst()) {
            #expect(smaller.width <= larger.width)
            #expect(smaller.height < larger.height)
            #expect(smaller.cornerRadius < larger.cornerRadius)
        }
    }

    @Test func levelsAreOrdered() {
        #expect(IslandLevel.allCases.sorted() == [.compact, .peek, .open])
        #expect(IslandLevel.compact < .peek)
        #expect(IslandLevel.peek < .open)
    }
}
