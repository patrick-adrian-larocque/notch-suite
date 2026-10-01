import Testing

@testable import NotchCore

@MainActor
@Suite struct ManualSchedulerTests {
    @Test func runsActionOnlyOnceItsDelayElapses() {
        let scheduler = ManualScheduler()
        var runs = 0
        _ = scheduler.schedule(after: .milliseconds(100)) { runs += 1 }

        scheduler.advance(milliseconds: 99)
        #expect(runs == 0)
        scheduler.advance(milliseconds: 1)
        #expect(runs == 1)
        scheduler.advance(milliseconds: 1000)
        #expect(runs == 1)
    }

    @Test func zeroDelayRunsOnAdvanceNotOnSchedule() {
        let scheduler = ManualScheduler()
        var runs = 0
        _ = scheduler.schedule(after: .zero) { runs += 1 }
        #expect(runs == 0)
        scheduler.advance(by: .zero)
        #expect(runs == 1)
    }

    @Test func cancelledActionNeverRuns() {
        let scheduler = ManualScheduler()
        var runs = 0
        let handle = scheduler.schedule(after: .milliseconds(10)) { runs += 1 }
        handle.cancel()
        scheduler.advance(milliseconds: 100)
        #expect(runs == 0)
        #expect(scheduler.pendingCount == 0)
    }

    @Test func runsActionsInDeadlineOrderAndAtTheirOwnTime() {
        let scheduler = ManualScheduler()
        var log: [String] = []
        _ = scheduler.schedule(after: .milliseconds(30)) { log.append("b@\(scheduler.now)") }
        _ = scheduler.schedule(after: .milliseconds(10)) { log.append("a@\(scheduler.now)") }
        scheduler.advance(milliseconds: 50)
        #expect(log == ["a@\(Duration.milliseconds(10))", "b@\(Duration.milliseconds(30))"])
        #expect(scheduler.now == .milliseconds(50))
    }

    @Test func runsActionsScheduledWhileAdvancingIfTheyFallDue() {
        let scheduler = ManualScheduler()
        var runs = 0
        _ = scheduler.schedule(after: .milliseconds(10)) {
            _ = scheduler.schedule(after: .milliseconds(10)) { runs += 1 }
        }
        scheduler.advance(milliseconds: 20)
        #expect(runs == 1)
    }
}
