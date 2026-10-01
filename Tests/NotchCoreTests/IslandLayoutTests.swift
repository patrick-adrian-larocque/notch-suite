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

    @Test(arguments: IslandMode.allCases)
    func compactWidthFollowsTheNotch(mode: IslandMode) {
        let design = IslandLayout.design.size(for: mode, at: .compact)
        let wider = IslandLayout(notchWidth: 210).size(for: mode, at: .compact)
        #expect(wider.width == design.width + 14)
        #expect(wider.height == design.height)
        #expect(wider.cornerRadius == design.cornerRadius)
    }

    @Test(arguments: IslandMode.allCases, [IslandLevel.peek, .open])
    func peekAndOpenIgnoreTheNotch(mode: IslandMode, level: IslandLevel) {
        #expect(
            IslandLayout(notchWidth: 210).size(for: mode, at: level)
                == IslandLayout.design.size(for: mode, at: level))
    }

    @Test(arguments: IslandMode.allCases)
    func eachLevelIsAtLeastAsLargeAsTheOneBelow(mode: IslandMode) {
        let sizes = IslandLevel.allCases.sorted().map {
            IslandLayout.design.size(for: mode, at: $0)
        }
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
