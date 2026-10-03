import Foundation
import Testing

@testable import NotchCore

/// Uses real time, so every wait is short and every check allows for a slow machine:
/// an action must not run early, and gets generous time to run late.
@MainActor
@Suite struct TaskDelaySchedulerTests {
    let scheduler = TaskDelayScheduler()

    /// Suspends the test until `condition` holds, or about a second has passed.
    private func waitUntil(_ condition: () -> Bool) async {
        var attempts = 0
        while !condition(), attempts < 200 {
            attempts += 1
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    /// Holds the main actor without suspending, which `Thread.sleep` can't do from an
    /// async function directly.
    private func blockTheMainActor(seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    @Test func runsTheActionAfterTheDelay() async throws {
        let clock = ContinuousClock()
        let start = clock.now
        var ranAt: ContinuousClock.Instant?
        _ = scheduler.schedule(after: .milliseconds(30)) { ranAt = clock.now }
        await waitUntil { ranAt != nil }
        let elapsed = try #require(ranAt) - start
        #expect(elapsed >= .milliseconds(30))
    }

    @Test func zeroDelayRunsLaterNeverInsideTheCall() async {
        var ran = false
        _ = scheduler.schedule(after: .zero) { ran = true }
        #expect(ran == false)
        await waitUntil { ran }
        #expect(ran)
    }

    @Test func cancelBeforeTheDelayEndsStopsTheAction() async {
        var ran = false
        let pending = scheduler.schedule(after: .milliseconds(20)) { ran = true }
        pending.cancel()
        try? await Task.sleep(for: .milliseconds(80))
        #expect(ran == false)
    }

    @Test func cancelAfterTheDelayElapsedButBeforeTheActionRanStopsIt() async {
        var ran = false
        let pending = scheduler.schedule(after: .milliseconds(10)) { ran = true }
        // Let the scheduled task run up to its sleep. It was queued on the main actor
        // before this test's continuation, so a yield runs it first.
        for _ in 0..<3 { await Task.yield() }
        // Block the main actor past the delay: the sleep finishes and the task is ready
        // to run the action, but can't until the main actor is free. A finished sleep no
        // longer throws, so only the check after it stops the action. (A scheduler that
        // relied on the sleep throwing fails this test and passes the one above.)
        blockTheMainActor(seconds: 0.05)
        pending.cancel()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(ran == false)
    }

    @Test func cancellingAfterTheActionRanOrTwiceDoesNothing() async {
        var runs = 0
        let pending = scheduler.schedule(after: .zero) { runs += 1 }
        await waitUntil { runs > 0 }
        pending.cancel()
        pending.cancel()
        try? await Task.sleep(for: .milliseconds(20))
        #expect(runs == 1)
    }

    @Test func delaysAreIndependent() async {
        var ran: [String] = []
        let first = scheduler.schedule(after: .milliseconds(10)) { ran.append("first") }
        _ = scheduler.schedule(after: .milliseconds(10)) { ran.append("second") }
        first.cancel()
        await waitUntil { !ran.isEmpty }
        try? await Task.sleep(for: .milliseconds(30))
        #expect(ran == ["second"])
    }

    @Test func drivesTheStateMachine() async {
        let machine = IslandStateMachine(
            settings: IslandSettings(hoverDelayMilliseconds: 10), scheduler: scheduler)
        machine.pointerEntered()
        #expect(machine.level == .compact)
        await waitUntil { machine.level == .peek }
        #expect(machine.level == .peek)
    }
}
