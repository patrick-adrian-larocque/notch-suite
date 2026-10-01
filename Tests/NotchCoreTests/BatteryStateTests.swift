import Testing

@testable import NotchCore

@Suite struct BatteryStateTests {
    @Test func keepsValidValues() {
        let state = BatteryState(percent: 42, isCharging: true, minutesToFull: 75)
        #expect(state.percent == 42)
        #expect(state.isCharging)
        #expect(state.minutesToFull == 75)
        #expect(!state.isFull)
    }

    @Test(arguments: [(-10, 0), (0, 0), (100, 100), (150, 100)])
    func percentIsClamped(input: Int, expected: Int) {
        #expect(BatteryState(percent: input, isCharging: false).percent == expected)
        var state = BatteryState(percent: 50, isCharging: false)
        state.percent = input
        #expect(state.percent == expected)
    }

    @Test func fullAtOneHundredPercent() {
        #expect(BatteryState(percent: 100, isCharging: true).isFull)
        #expect(!BatteryState(percent: 99, isCharging: true).isFull)
    }

    @Test func minutesToFullNeedsCharging() {
        #expect(
            BatteryState(percent: 50, isCharging: false, minutesToFull: 30).minutesToFull == nil)
        var state = BatteryState(percent: 50, isCharging: false)
        state.minutesToFull = 30
        #expect(state.minutesToFull == nil)
    }

    @Test func negativeMinutesToFullIsUnknown() {
        #expect(BatteryState(percent: 50, isCharging: true, minutesToFull: -1).minutesToFull == nil)
        var state = BatteryState(percent: 50, isCharging: true, minutesToFull: 20)
        state.minutesToFull = -5
        #expect(state.minutesToFull == nil)
    }

    @Test func unpluggingClearsMinutesToFull() {
        var state = BatteryState(percent: 50, isCharging: true, minutesToFull: 20)
        state.isCharging = false
        #expect(state.minutesToFull == nil)
    }
}
