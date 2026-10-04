import Foundation
import Testing

@testable import NotchCore

@Suite struct PlaybackProgressTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    private func track(
        playing: Bool = true, duration: Double? = 180, elapsed: Double? = 60, rate: Double? = 1
    ) -> NowPlaying {
        NowPlaying(
            app: AppIdentity(bundleIdentifier: "com.apple.Music"), playing: playing, title: "Song",
            duration: duration, elapsedTime: elapsed, playbackRate: rate)
    }

    private func progress(_ nowPlaying: NowPlaying) throws -> PlaybackProgress {
        try #require(PlaybackProgress(nowPlaying: nowPlaying, sampledAt: start))
    }

    // MARK: Extrapolation

    @Test func playingExtrapolatesFromTheSample() throws {
        let progress = try progress(track())
        #expect(progress.elapsed(at: start) == 60)
        #expect(progress.elapsed(at: start + 5) == 65)
        #expect(progress.remaining(at: start + 5) == 115)
        #expect(progress.fraction(at: start + 30) == 0.5)
    }

    @Test func pausedDoesNotAdvance() throws {
        let progress = try progress(track(playing: false))
        #expect(progress.playbackRate == 0)
        #expect(progress.elapsed(at: start + 30) == 60)
        #expect(progress.fraction(at: start + 30) == 60.0 / 180)
    }

    @Test func pausedIgnoresAStaleNonZeroRate() throws {
        // Some players leave playbackRate at 1 when they pause.
        let progress = try progress(track(playing: false, rate: 1))
        #expect(progress.elapsed(at: start + 30) == 60)
    }

    @Test func rateZeroWhilePlayingDoesNotAdvance() throws {
        // Buffering: the player says it is playing, but the clock is stopped.
        let progress = try progress(track(playing: true, rate: 0))
        #expect(progress.elapsed(at: start + 30) == 60)
        #expect(progress.remainingText(at: start + 30) == "-2:00")
    }

    @Test func missingRateWhilePlayingAssumesNormalSpeed() throws {
        let progress = try progress(track(rate: nil))
        #expect(progress.playbackRate == 1)
        #expect(progress.elapsed(at: start + 10) == 70)
    }

    @Test func fasterRateAdvancesFaster() throws {
        let progress = try progress(track(rate: 2))
        #expect(progress.elapsed(at: start + 10) == 80)
    }

    @Test func negativeRateStopsAtZero() throws {
        let progress = try progress(track(elapsed: 5, rate: -1))
        #expect(progress.elapsed(at: start + 3) == 2)
        #expect(progress.elapsed(at: start + 30) == 0)
    }

    @Test func clockBeforeTheSampleDoesNotRewind() throws {
        let progress = try progress(track())
        #expect(progress.elapsed(at: start - 10) == 60)
    }

    // MARK: Over-run

    @Test func overRunClampsToTheDuration() throws {
        let progress = try progress(track(duration: 180, elapsed: 170))
        #expect(progress.elapsed(at: start + 60) == 180)
        #expect(progress.remaining(at: start + 60) == 0)
        #expect(progress.fraction(at: start + 60) == 1)
        #expect(progress.elapsedText(at: start + 60) == "3:00")
        #expect(progress.remainingText(at: start + 60) == "-0:00")
    }

    @Test func reportedElapsedPastTheDurationClamps() throws {
        let progress = try progress(track(duration: 180, elapsed: 200, rate: 0))
        #expect(progress.elapsed(at: start) == 180)
        #expect(progress.fraction(at: start) == 1)
    }

    @Test func negativeElapsedReadsAsZero() throws {
        let progress = try progress(track(elapsed: -4, rate: 0))
        #expect(progress.elapsedTime == 0)
        #expect(progress.fraction(at: start) == 0)
    }

    // MARK: Unknown duration

    @Test func unknownDurationHasNoFractionOrRemaining() throws {
        let progress = try progress(track(duration: nil))
        #expect(progress.duration == nil)
        #expect(progress.fraction(at: start) == nil)
        #expect(progress.remaining(at: start) == nil)
        #expect(progress.remainingText(at: start) == nil)
        // Elapsed still counts, with no upper bound.
        #expect(progress.elapsed(at: start + 600) == 660)
        #expect(progress.elapsedText(at: start + 600) == "11:00")
    }

    @Test(arguments: [0, -1, Double.nan, Double.infinity])
    func unusableDurationReadsAsUnknown(duration: Double) throws {
        let progress = try progress(track(duration: duration))
        #expect(progress.duration == nil)
        #expect(progress.fraction(at: start) == nil)
    }

    @Test func missingElapsedHasNoProgress() {
        #expect(PlaybackProgress(nowPlaying: track(elapsed: nil), sampledAt: start) == nil)
    }

    @Test func nonFiniteValuesAreMadeSafe() {
        let progress = PlaybackProgress(
            elapsedTime: .nan, duration: 100, playbackRate: .infinity, sampledAt: start)
        #expect(progress.elapsedTime == 0)
        #expect(progress.playbackRate == 0)
        #expect(progress.elapsed(at: start + 10) == 0)
    }

    // MARK: Labels

    @Test func labelsRoundSoTheyAddUpToTheDuration() throws {
        let progress = try progress(track(duration: 180, elapsed: 0))
        #expect(progress.elapsedText(at: start + 0.4) == "0:00")
        #expect(progress.remainingText(at: start + 0.4) == "-3:00")
        #expect(progress.elapsedText(at: start + 65.5) == "1:05")
        #expect(progress.remainingText(at: start + 65.5) == "-1:55")
    }
}

@Suite struct PlaybackTimeFormatTests {
    @Test(arguments: [
        (0, "0:00"), (5, "0:05"), (59, "0:59"), (60, "1:00"), (605, "10:05"),
        (3599, "59:59"), (3600, "1:00:00"), (3725, "1:02:05"), (-3, "0:00"),
    ])
    func formatsWholeSeconds(seconds: Int, expected: String) {
        #expect(PlaybackTimeFormat.string(wholeSeconds: seconds) == expected)
    }

    @Test func elapsedRoundsDown() {
        #expect(PlaybackTimeFormat.elapsed(59.9) == "0:59")
    }

    @Test func remainingRoundsUpWithAMinus() {
        #expect(PlaybackTimeFormat.remaining(59.1) == "-1:00")
        #expect(PlaybackTimeFormat.remaining(0) == "-0:00")
    }

    @Test(arguments: [Double.nan, -Double.infinity, -1])
    func unusableSecondsReadAsZero(seconds: Double) {
        #expect(PlaybackTimeFormat.elapsed(seconds) == "0:00")
        #expect(PlaybackTimeFormat.remaining(seconds) == "-0:00")
    }

    @Test func hugeValuesDoNotTrap() {
        #expect(PlaybackTimeFormat.elapsed(.infinity) == "0:00")
        #expect(!PlaybackTimeFormat.elapsed(1e300).isEmpty)
    }
}
