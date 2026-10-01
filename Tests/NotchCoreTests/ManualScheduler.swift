@testable import NotchCore

/// A `DelayScheduler` whose time moves only when a test calls `advance(by:)`.
@MainActor
final class ManualScheduler: DelayScheduler {
    private final class Entry: ScheduledDelay {
        let deadline: Duration
        let order: Int
        var action: (@MainActor () -> Void)?

        init(deadline: Duration, order: Int, action: @escaping @MainActor () -> Void) {
            self.deadline = deadline
            self.order = order
            self.action = action
        }

        func cancel() {
            action = nil
        }
    }

    /// Time elapsed since the scheduler was created.
    private(set) var now: Duration = .zero
    private var entries: [Entry] = []
    private var nextOrder = 0

    /// How many actions are scheduled and not yet run or cancelled.
    var pendingCount: Int { entries.filter { $0.action != nil }.count }

    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void)
        -> any ScheduledDelay
    {
        let entry = Entry(deadline: now + delay, order: nextOrder, action: action)
        nextOrder += 1
        entries.append(entry)
        return entry
    }

    /// Moves time forward, running every action that falls due, in deadline order.
    ///
    /// Actions scheduled while advancing also run if they fall due within the window.
    func advance(by duration: Duration) {
        let target = now + duration
        while let entry = nextDue(by: target) {
            now = entry.deadline
            let action = entry.action
            entry.action = nil
            action?()
        }
        now = target
        entries.removeAll { $0.action == nil }
    }

    func advance(milliseconds: Int) {
        advance(by: .milliseconds(milliseconds))
    }

    private func nextDue(by target: Duration) -> Entry? {
        entries
            .filter { $0.action != nil && $0.deadline <= target }
            .min { ($0.deadline, $0.order) < ($1.deadline, $1.order) }
    }
}
