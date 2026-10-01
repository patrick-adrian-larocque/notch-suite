import Observation
import Testing

@testable import NotchCore

/// Fake-clock tests for `IslandStateMachine`, with the default settings unless a test
/// says otherwise: hover delay 120 ms, leave delay 350 ms, collapse delay 1200 ms,
/// alert collapse 4 s.
@MainActor
@Suite struct IslandStateMachineTests {
    let scheduler = ManualScheduler()

    func makeMachine(
        mode: IslandMode = .nowPlaying, settings: IslandSettings = .defaults
    ) -> IslandStateMachine {
        IslandStateMachine(mode: mode, settings: settings, scheduler: scheduler)
    }

    /// Hovers until the hover delay has elapsed.
    func hoverToPeek(_ machine: IslandStateMachine) {
        machine.pointerEntered()
        scheduler.advance(milliseconds: machine.settings.hoverDelayMilliseconds)
    }

    @Test func startsCompactWithNothingPending() {
        let machine = makeMachine()
        #expect(machine.mode == .nowPlaying)
        #expect(machine.level == .compact)
        #expect(machine.displayedLevel == .compact)
        #expect(machine.alert == nil)
        #expect(machine.hud == nil)
        #expect(!machine.isHovered)
        #expect(scheduler.pendingCount == 0)
    }

    @Test func levelChangesAreObservable() {
        let machine = makeMachine()
        let changed = ChangeFlag()
        withObservationTracking {
            _ = machine.level
        } onChange: {
            changed.set()
        }
        machine.click()
        #expect(changed.value)
    }

    // MARK: Hover

    @Test func hoverPeeksAfterTheHoverDelay() {
        let machine = makeMachine()
        machine.pointerEntered()
        scheduler.advance(milliseconds: 119)
        #expect(machine.level == .compact)
        scheduler.advance(milliseconds: 1)
        #expect(machine.level == .peek)
    }

    @Test func hoverOpensWhenHoverActionIsOpen() {
        let machine = makeMachine(settings: IslandSettings(hoverAction: .open))
        hoverToPeek(machine)
        #expect(machine.level == .open)
    }

    @Test func hoverDoesNothingWhenHoverActionIsOff() {
        let machine = makeMachine(settings: IslandSettings(hoverAction: .off))
        machine.pointerEntered()
        #expect(scheduler.pendingCount == 0)
        scheduler.advance(milliseconds: 5000)
        #expect(machine.level == .compact)
    }

    @Test func hoverUsesTheHoverDelaySetting() {
        let machine = makeMachine(settings: IslandSettings(hoverDelayMilliseconds: 400))
        machine.pointerEntered()
        scheduler.advance(milliseconds: 399)
        #expect(machine.level == .compact)
        scheduler.advance(milliseconds: 1)
        #expect(machine.level == .peek)
    }

    @Test func settingsChangesApplyToLaterDelays() {
        let machine = makeMachine()
        machine.settings.hoverDelayMilliseconds = 300
        machine.pointerEntered()
        scheduler.advance(milliseconds: 299)
        #expect(machine.level == .compact)
        scheduler.advance(milliseconds: 1)
        #expect(machine.level == .peek)
    }

    @Test func leavingDuringTheHoverDelayCancelsIt() {
        let machine = makeMachine()
        machine.pointerEntered()
        scheduler.advance(milliseconds: 100)
        machine.pointerLeft()
        scheduler.advance(milliseconds: 5000)
        #expect(machine.level == .compact)
        #expect(scheduler.pendingCount == 0)
    }

    @Test func reenteringDuringTheHoverDelayRestartsIt() {
        let machine = makeMachine()
        machine.pointerEntered()
        scheduler.advance(milliseconds: 100)
        machine.pointerLeft()
        scheduler.advance(milliseconds: 10)
        machine.pointerEntered()
        scheduler.advance(milliseconds: 119)
        #expect(machine.level == .compact)
        scheduler.advance(milliseconds: 1)
        #expect(machine.level == .peek)
    }

    @Test func repeatedEnterEventsDoNotRestartTheHoverDelay() {
        let machine = makeMachine()
        machine.pointerEntered()
        scheduler.advance(milliseconds: 100)
        machine.pointerEntered()
        scheduler.advance(milliseconds: 20)
        #expect(machine.level == .peek)
    }

    // MARK: Leave

    @Test func leavingPeekReturnsToCompactAfterTheLeaveDelay() {
        let machine = makeMachine()
        hoverToPeek(machine)
        machine.pointerLeft()
        scheduler.advance(milliseconds: 349)
        #expect(machine.level == .peek)
        scheduler.advance(milliseconds: 1)
        #expect(machine.level == .compact)
    }

    @Test func reenteringDuringTheLeaveDelayKeepsTheIslandOpen() {
        let machine = makeMachine()
        hoverToPeek(machine)
        machine.pointerLeft()
        scheduler.advance(milliseconds: 300)
        machine.pointerEntered()
        scheduler.advance(milliseconds: 5000)
        #expect(machine.level == .peek)
        #expect(scheduler.pendingCount == 0)
    }

    @Test func leavingAgainAfterReentryRestartsTheLeaveDelay() {
        let machine = makeMachine()
        hoverToPeek(machine)
        machine.pointerLeft()
        scheduler.advance(milliseconds: 300)
        machine.pointerEntered()
        machine.pointerLeft()
        scheduler.advance(milliseconds: 349)
        #expect(machine.level == .peek)
        scheduler.advance(milliseconds: 1)
        #expect(machine.level == .compact)
    }

    @Test func leavingCompactSchedulesNothing() {
        let machine = makeMachine()
        machine.pointerEntered()
        machine.pointerLeft()
        #expect(scheduler.pendingCount == 0)
        #expect(machine.level == .compact)
    }

    @Test func leavingOpenCollapsesAfterTheCollapseDelay() {
        let machine = makeMachine()
        machine.pointerEntered()
        machine.click()
        machine.pointerLeft()
        scheduler.advance(milliseconds: 1199)
        #expect(machine.level == .open)
        scheduler.advance(milliseconds: 1)
        #expect(machine.level == .compact)
    }

    @Test func leavingOpenStaysOpenWhenCollapseOnLeaveIsOff() {
        let machine = makeMachine(settings: IslandSettings(collapseOnLeave: false))
        machine.pointerEntered()
        machine.click()
        machine.pointerLeft()
        #expect(scheduler.pendingCount == 0)
        scheduler.advance(milliseconds: 10_000)
        #expect(machine.level == .open)
    }

    @Test func leavingAnOpenAlertCollapsesEvenWhenCollapseOnLeaveIsOff() {
        let machine = makeMachine(settings: IslandSettings(collapseOnLeave: false))
        machine.alertArrived(.charging)
        machine.pointerEntered()
        scheduler.advance(milliseconds: 4000)
        #expect(machine.level == .open)
        machine.pointerLeft()
        scheduler.advance(milliseconds: 1199)
        #expect(machine.level == .open)
        scheduler.advance(milliseconds: 1)
        #expect(machine.level == .compact)
    }

    @Test func leavingOpenUsesTheLeaveDelayWhenHoverOpens() {
        let settings = IslandSettings(hoverAction: .open, collapseOnLeave: false)
        let machine = makeMachine(settings: settings)
        hoverToPeek(machine)
        #expect(machine.level == .open)
        machine.pointerLeft()
        scheduler.advance(milliseconds: 349)
        #expect(machine.level == .open)
        scheduler.advance(milliseconds: 1)
        #expect(machine.level == .compact)
    }

    @Test func reenteringDuringTheCollapseDelayKeepsTheIslandOpen() {
        let machine = makeMachine()
        machine.click()
        machine.pointerEntered()
        machine.pointerLeft()
        scheduler.advance(milliseconds: 1000)
        machine.pointerEntered()
        scheduler.advance(milliseconds: 5000)
        #expect(machine.level == .open)
    }

    // MARK: Keyboard focus

    @Test func focusCountsAsHover() {
        let machine = makeMachine()
        machine.focusGained()
        #expect(machine.isHovered)
        scheduler.advance(milliseconds: 120)
        #expect(machine.level == .peek)
    }

    @Test func losingFocusCountsAsLeaving() {
        let machine = makeMachine()
        machine.focusGained()
        scheduler.advance(milliseconds: 120)
        machine.focusLost()
        scheduler.advance(milliseconds: 349)
        #expect(machine.level == .peek)
        scheduler.advance(milliseconds: 1)
        #expect(machine.level == .compact)
    }

    @Test func pointerLeavingKeepsTheIslandWhileItHasFocus() {
        let machine = makeMachine()
        hoverToPeek(machine)
        machine.focusGained()
        machine.pointerLeft()
        scheduler.advance(milliseconds: 5000)
        #expect(machine.level == .peek)
        machine.focusLost()
        scheduler.advance(milliseconds: 350)
        #expect(machine.level == .compact)
    }

    @Test func losingFocusKeepsTheIslandWhileThePointerIsOnIt() {
        let machine = makeMachine()
        machine.focusGained()
        scheduler.advance(milliseconds: 120)
        machine.pointerEntered()
        machine.focusLost()
        scheduler.advance(milliseconds: 5000)
        #expect(machine.level == .peek)
    }

    @Test func focusDuringTheLeaveDelayCancelsIt() {
        let machine = makeMachine()
        hoverToPeek(machine)
        machine.pointerLeft()
        scheduler.advance(milliseconds: 200)
        machine.focusGained()
        scheduler.advance(milliseconds: 5000)
        #expect(machine.level == .peek)
    }

    // MARK: Click and collapse

    @Test func clickOpensAtOnce() {
        let machine = makeMachine()
        machine.click()
        #expect(machine.level == .open)
    }

    @Test func clickCancelsAPendingHoverDelay() {
        let machine = makeMachine(settings: IslandSettings(collapseOnLeave: false))
        machine.pointerEntered()
        machine.click()
        #expect(scheduler.pendingCount == 0)
        scheduler.advance(milliseconds: 5000)
        #expect(machine.level == .open)
    }

    @Test func clickCancelsAPendingLeaveDelay() {
        let machine = makeMachine()
        hoverToPeek(machine)
        machine.pointerLeft()
        machine.click()
        scheduler.advance(milliseconds: 5000)
        #expect(machine.level == .open)
    }

    @Test func collapseReturnsToCompactAtOnce() {
        let machine = makeMachine()
        machine.pointerEntered()
        machine.click()
        machine.collapse()
        #expect(machine.level == .compact)
    }

    @Test func collapseUnderThePointerDoesNotPeekAgain() {
        let machine = makeMachine()
        hoverToPeek(machine)
        machine.click()
        machine.collapse()
        #expect(scheduler.pendingCount == 0)
        scheduler.advance(milliseconds: 5000)
        #expect(machine.level == .compact)
    }

    @Test func collapseCancelsAPendingAlertDelay() {
        let machine = makeMachine()
        machine.alertArrived(.charging)
        machine.collapse()
        #expect(scheduler.pendingCount == 0)
        #expect(machine.level == .compact)
    }

    // MARK: Alerts

    @Test func alertArrivesOpenAndCollapsesAfterTheAlertDelay() {
        let machine = makeMachine()
        machine.alertArrived(.charging)
        #expect(machine.mode == .charging)
        #expect(machine.alert == .charging)
        #expect(machine.level == .open)
        scheduler.advance(milliseconds: 3999)
        #expect(machine.level == .open)
        scheduler.advance(milliseconds: 1)
        #expect(machine.level == .compact)
        #expect(machine.mode == .charging)
    }

    @Test func finishedTimerAlertShowsTheTimerMode() {
        let machine = makeMachine()
        machine.alertArrived(.timerFinished)
        #expect(machine.mode == .timer)
        #expect(machine.level == .open)
    }

    @Test func alertUsesTheAlertCollapseSetting() {
        let machine = makeMachine(settings: IslandSettings(alertCollapseSeconds: 2))
        machine.alertArrived(.charging)
        scheduler.advance(milliseconds: 1999)
        #expect(machine.level == .open)
        scheduler.advance(milliseconds: 1)
        #expect(machine.level == .compact)
    }

    @Test func alertArrivesCompactWhenAlertExpandIsOff() {
        let machine = makeMachine(settings: IslandSettings(alertExpand: false))
        machine.alertArrived(.charging)
        #expect(machine.mode == .charging)
        #expect(machine.level == .compact)
        #expect(scheduler.pendingCount == 0)
    }

    @Test func alertStaysOpenWhileThePointerIsOnIt() {
        let machine = makeMachine()
        machine.alertArrived(.charging)
        machine.pointerEntered()
        scheduler.advance(milliseconds: 10_000)
        #expect(machine.level == .open)
    }

    @Test func alertStaysOpenWhileTheIslandHasFocus() {
        let machine = makeMachine()
        machine.alertArrived(.timerFinished)
        machine.focusGained()
        scheduler.advance(milliseconds: 10_000)
        #expect(machine.level == .open)
    }

    @Test func alertCancelsAPendingHoverDelay() {
        let machine = makeMachine(settings: IslandSettings(alertExpand: false))
        machine.pointerEntered()
        machine.alertArrived(.charging)
        scheduler.advance(milliseconds: 5000)
        #expect(machine.level == .compact)
    }

    @Test func secondAlertRestartsTheAlertDelay() {
        let machine = makeMachine()
        machine.alertArrived(.charging)
        scheduler.advance(milliseconds: 3000)
        machine.alertArrived(.timerFinished)
        scheduler.advance(milliseconds: 3999)
        #expect(machine.mode == .timer)
        #expect(machine.level == .open)
        scheduler.advance(milliseconds: 1)
        #expect(machine.level == .compact)
    }

    // MARK: Selecting a mode

    @Test func selectingAModeShowsItCompact() {
        let machine = makeMachine()
        machine.click()
        machine.selectMode(.shelf)
        #expect(machine.mode == .shelf)
        #expect(machine.level == .compact)
    }

    @Test func selectingAModeCancelsPendingDelays() {
        let machine = makeMachine()
        machine.alertArrived(.charging)
        machine.pointerEntered()
        machine.pointerLeft()
        #expect(scheduler.pendingCount == 2)
        machine.selectMode(.nowPlaying)
        #expect(scheduler.pendingCount == 0)
    }

    @Test func selectingAModeCancelsAPendingHoverDelay() {
        let machine = makeMachine()
        machine.pointerEntered()
        machine.selectMode(.timer)
        scheduler.advance(milliseconds: 5000)
        #expect(machine.level == .compact)
    }

    @Test func selectingAModeClearsTheAlert() {
        let machine = makeMachine(settings: IslandSettings(collapseOnLeave: false))
        machine.alertArrived(.charging)
        machine.selectMode(.charging)
        #expect(machine.alert == nil)
        machine.pointerEntered()
        machine.click()
        machine.pointerLeft()
        #expect(scheduler.pendingCount == 0)
    }

    // MARK: HUD takeover

    @Test func hudTakesOverAtPeekForOnePointFiveSeconds() {
        let machine = makeMachine()
        machine.hudKeyPressed(.volume)
        #expect(machine.hud == .volume)
        #expect(machine.displayedLevel == .peek)
        scheduler.advance(milliseconds: 1499)
        #expect(machine.hud == .volume)
        scheduler.advance(milliseconds: 1)
        #expect(machine.hud == nil)
        #expect(machine.displayedLevel == .compact)
    }

    @Test func hudHandsBackToThePreviousModeAndLevel() {
        let machine = makeMachine(mode: .shelf, settings: IslandSettings(collapseOnLeave: false))
        machine.click()
        machine.hudKeyPressed(.brightness)
        #expect(machine.displayedLevel == .peek)
        #expect(machine.mode == .shelf)
        #expect(machine.level == .open)
        scheduler.advance(by: IslandStateMachine.hudDuration)
        #expect(machine.hud == nil)
        #expect(machine.mode == .shelf)
        #expect(machine.displayedLevel == .open)
    }

    @Test func hudHandsBackToAHoveredPeek() {
        let machine = makeMachine()
        hoverToPeek(machine)
        machine.hudKeyPressed(.volume)
        scheduler.advance(milliseconds: 1500)
        #expect(machine.mode == .nowPlaying)
        #expect(machine.displayedLevel == .peek)
        #expect(machine.hud == nil)
    }

    @Test func repeatedPressesExtendTheHud() {
        let machine = makeMachine()
        machine.hudKeyPressed(.volume)
        scheduler.advance(milliseconds: 1000)
        machine.hudKeyPressed(.volume)
        scheduler.advance(milliseconds: 1000)
        #expect(machine.hud == .volume)
        scheduler.advance(milliseconds: 499)
        #expect(machine.hud == .volume)
        scheduler.advance(milliseconds: 1)
        #expect(machine.hud == nil)
        #expect(scheduler.pendingCount == 0)
    }

    @Test func pressingAnotherHudKeySwitchesAndExtends() {
        let machine = makeMachine()
        machine.hudKeyPressed(.volume)
        scheduler.advance(milliseconds: 1000)
        machine.hudKeyPressed(.keyboardBrightness)
        #expect(machine.hud == .keyboardBrightness)
        scheduler.advance(milliseconds: 1499)
        #expect(machine.hud == .keyboardBrightness)
        scheduler.advance(milliseconds: 1)
        #expect(machine.hud == nil)
    }

    @Test func hudIsIgnoredWhenReplaceSystemHUDsIsOff() {
        let machine = makeMachine(settings: IslandSettings(replaceSystemHUDs: false))
        machine.hudKeyPressed(.volume)
        #expect(machine.hud == nil)
        #expect(scheduler.pendingCount == 0)
    }

    @Test func clickEndsTheHud() {
        let machine = makeMachine()
        machine.hudKeyPressed(.volume)
        machine.click()
        #expect(machine.hud == nil)
        #expect(machine.displayedLevel == .open)
    }

    @Test func collapseEndsTheHud() {
        let machine = makeMachine()
        machine.click()
        machine.hudKeyPressed(.volume)
        machine.collapse()
        #expect(machine.hud == nil)
        #expect(machine.displayedLevel == .compact)
        #expect(scheduler.pendingCount == 0)
        scheduler.advance(milliseconds: 5000)
        #expect(machine.displayedLevel == .compact)
    }

    @Test func alertEndsTheHud() {
        let machine = makeMachine()
        machine.hudKeyPressed(.brightness)
        machine.alertArrived(.charging)
        #expect(machine.hud == nil)
        #expect(machine.displayedLevel == .open)
    }

    @Test func selectingAModeEndsTheHud() {
        let machine = makeMachine()
        machine.hudKeyPressed(.brightness)
        machine.selectMode(.timer)
        #expect(machine.hud == nil)
        #expect(scheduler.pendingCount == 0)
    }

    @Test func islandDelaysKeepRunningUnderTheHud() {
        let machine = makeMachine()
        hoverToPeek(machine)
        machine.pointerLeft()
        machine.hudKeyPressed(.volume)
        scheduler.advance(milliseconds: 350)
        #expect(machine.level == .compact)
        #expect(machine.displayedLevel == .peek)
        scheduler.advance(milliseconds: 1150)
        #expect(machine.displayedLevel == .compact)
    }
}

/// Records that an observation fired.
///
/// `@unchecked Sendable` because `onChange` must be `@Sendable`, but Observation calls it
/// synchronously from the mutation, which these tests make on the main actor, so the
/// flag is only ever touched from one thread.
final class ChangeFlag: @unchecked Sendable {
    private(set) var value = false

    func set() {
        value = true
    }
}
