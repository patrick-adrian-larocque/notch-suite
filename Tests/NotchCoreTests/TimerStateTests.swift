import Testing

@testable import NotchCore

@Suite struct TimerStateTests {
    private func timer(_ total: Double = 300) throws -> TimerState {
        try #require(TimerState(totalSeconds: total))
    }

    @Test func newTimerRunsWithFullDuration() throws {
        let state = try timer(300)
        #expect(state.phase == .running)
        #expect(state.isRunning)
        #expect(!state.isDone)
        #expect(state.totalSeconds == 300)
        #expect(state.remainingSeconds == 300)
        #expect(state.elapsedSeconds == 0)
        #expect(state.fractionRemaining == 1)
    }

    @Test(arguments: [0, -5, Double.nan, Double.infinity])
    func invalidDurationIsRejected(total: Double) {
        #expect(TimerState(totalSeconds: total) == nil)
    }

    @Test func tickCountsDown() throws {
        var state = try timer(300)
        let finished = state.tick(by: 30)
        #expect(!finished)
        #expect(state.remainingSeconds == 270)
        #expect(state.elapsedSeconds == 30)
        #expect(state.fractionRemaining == 0.9)
        #expect(state.isRunning)
    }

    @Test func tickReachingZeroFinishesOnce() throws {
        var state = try timer(60)
        let finished = state.tick(by: 60)
        #expect(finished)
        #expect(state.phase == .done)
        #expect(state.remainingSeconds == 0)
        #expect(state.fractionRemaining == 0)
        // Later ticks don't report finishing again.
        let finishedAgain = state.tick(by: 1)
        #expect(!finishedAgain)
        #expect(state.phase == .done)
    }

    @Test func overshootingTickStopsAtZero() throws {
        var state = try timer(10)
        let finished = state.tick(by: 25)
        #expect(finished)
        #expect(state.remainingSeconds == 0)
        #expect(state.isDone)
    }

    @Test(arguments: [0, -1, Double.nan, Double.infinity, -Double.infinity])
    func invalidTicksChangeNothing(seconds: Double) throws {
        var state = try timer(100)
        let finished = state.tick(by: seconds)
        #expect(!finished)
        #expect(state == (try timer(100)))
    }

    @Test func pauseHoldsRemainingTime() throws {
        var state = try timer(100)
        state.tick(by: 40)
        state.pause()
        #expect(state.phase == .paused)
        #expect(!state.isRunning)
        state.tick(by: 30)
        #expect(state.remainingSeconds == 60)
    }

    @Test func resumeContinuesCountdown() throws {
        var state = try timer(100)
        state.tick(by: 40)
        state.pause()
        state.resume()
        #expect(state.phase == .running)
        state.tick(by: 10)
        #expect(state.remainingSeconds == 50)
    }

    @Test func pauseAndResumeOnlyApplyInTheirPhase() throws {
        var running = try timer(100)
        running.resume()
        #expect(running.phase == .running)

        var done = try timer(10)
        done.tick(by: 10)
        done.pause()
        #expect(done.phase == .done)
        done.resume()
        #expect(done.phase == .done)
    }

    @Test(arguments: [TimerState.Phase.running, .paused, .done])
    func restartRefillsAndRuns(from phase: TimerState.Phase) throws {
        var state = try timer(100)
        state.tick(by: 30)
        switch phase {
        case .running: break
        case .paused: state.pause()
        case .done: state.tick(by: 70)
        }
        #expect(state.phase == phase)

        state.restart()
        #expect(state.phase == .running)
        #expect(state.remainingSeconds == 100)
        #expect(state.totalSeconds == 100)
    }

    @Test func addMinuteExtendsRemainingWithinTotal() throws {
        var state = try timer(600)
        state.tick(by: 300)
        state.addMinute()
        #expect(state.remainingSeconds == 360)
        #expect(state.totalSeconds == 600)
        #expect(state.isRunning)
    }

    @Test func addMinuteGrowsTotalWhenNeeded() throws {
        var state = try timer(90)
        state.tick(by: 10)
        state.addMinute()
        #expect(state.remainingSeconds == 140)
        #expect(state.totalSeconds == 140)
        #expect(state.fractionRemaining == 1)
    }

    @Test func addMinuteKeepsPausedTimerPaused() throws {
        var state = try timer(300)
        state.pause()
        state.addMinute()
        #expect(state.phase == .paused)
        #expect(state.remainingSeconds == 360)
    }

    @Test func addMinuteRestartsDoneTimer() throws {
        var state = try timer(300)
        state.tick(by: 300)
        state.addMinute()
        #expect(state.phase == .running)
        #expect(state.remainingSeconds == TimerState.addedSeconds)
        #expect(state.totalSeconds == 300)
        let finished = state.tick(by: 60)
        #expect(finished)
        #expect(state.isDone)
    }

    @Test func restartAfterGrowingUsesNewTotal() throws {
        var state = try timer(30)
        state.addMinute()
        state.tick(by: 50)
        state.restart()
        #expect(state.remainingSeconds == 90)
    }
}
