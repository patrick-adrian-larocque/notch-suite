import Observation

/// An event that takes over the island.
///
/// It arrives open when ``IslandSettings/alertExpand`` is on, and compact otherwise.
public enum IslandAlert: String, Sendable, Hashable, CaseIterable {
    /// Power was connected.
    case charging
    /// A countdown timer reached zero.
    case timerFinished

    /// The mode the island shows for this alert.
    public var mode: IslandMode {
        switch self {
        case .charging: .charging
        case .timerFinished: .timer
        }
    }
}

/// A system HUD that briefly takes over the island when its key is pressed.
public enum SystemHUDKind: String, Sendable, Hashable, CaseIterable {
    case volume
    case brightness
    case keyboardBrightness
}

/// Decides the island's mode and level from pointer, focus, click and alert events.
///
/// The hover, leave, collapse and alert delays come from `settings`; the HUD uses the
/// fixed ``hudDuration``. Every delay runs on the injected ``DelayScheduler``, so the
/// rules are testable without real time. The rules follow the design prototype:
///
/// - Resting on the compact island for the hover delay grows it to peek, or to open
///   when ``IslandSettings/hoverAction`` is `.open`. Hover `.off` does nothing.
/// - Leaving a peek returns to compact after the leave delay. Leaving an open island
///   returns to compact after the leave delay when hover opens it, otherwise after the
///   collapse delay when ``IslandSettings/collapseOnLeave`` is on or an alert is
///   showing. Coming back before a delay ends cancels it.
/// - Keyboard focus counts as the pointer: the island is hovered while either is on it.
/// - A click opens the island and the collapse button returns it to compact, both at
///   once and cancelling every pending delay.
/// - An alert switches to its mode and, when ``IslandSettings/alertExpand`` is on,
///   arrives open and collapses after the alert delay unless the island is hovered.
/// - Selecting a mode shows it compact and cancels every pending delay.
/// - A HUD key press shows the HUD at peek size for ``hudDuration``. Further presses
///   restart that duration instead of replaying the takeover. When it ends, the island
///   shows its own ``mode`` and ``level`` again. A click, collapse, mode change or
///   alert ends the HUD at once.
@MainActor
@Observable
public final class IslandStateMachine {
    /// How long a HUD stays on the island after the last key press.
    public static let hudDuration: Duration = .milliseconds(1500)

    /// What the island shows when no HUD is on it.
    public private(set) var mode: IslandMode
    /// How far the island is expanded when no HUD is on it.
    public private(set) var level: IslandLevel = .compact
    /// The alert that set the current mode, or `nil` when the mode was selected.
    public private(set) var alert: IslandAlert?
    /// The HUD on the island, or `nil` when none is.
    public private(set) var hud: SystemHUDKind?
    /// Whether the pointer is over the island.
    public private(set) var isPointerInside = false
    /// Whether the island has keyboard focus.
    public private(set) var isFocused = false

    /// The timing and hover settings. Changes apply to delays scheduled afterwards.
    public var settings: IslandSettings

    /// Whether the island is hovered: the pointer is on it or it has keyboard focus.
    public var isHovered: Bool { isPointerInside || isFocused }

    /// The level to draw: peek while a HUD is showing, otherwise ``level``.
    public var displayedLevel: IslandLevel { hud == nil ? level : .peek }

    @ObservationIgnored private let scheduler: any DelayScheduler
    @ObservationIgnored private var hoverDelay: (any ScheduledDelay)?
    @ObservationIgnored private var leaveDelay: (any ScheduledDelay)?
    @ObservationIgnored private var alertDelay: (any ScheduledDelay)?
    @ObservationIgnored private var hudDelay: (any ScheduledDelay)?

    /// Creates a state machine showing `mode` compact.
    public init(
        mode: IslandMode = .idle,
        settings: IslandSettings = .defaults,
        scheduler: any DelayScheduler
    ) {
        self.mode = mode
        self.settings = settings
        self.scheduler = scheduler
    }

    // MARK: Inputs

    /// The pointer moved onto the island.
    public func pointerEntered() {
        guard !isPointerInside else { return }
        let wasHovered = isHovered
        isPointerInside = true
        if !wasHovered { hoverBegan() }
    }

    /// The pointer moved off the island.
    public func pointerLeft() {
        guard isPointerInside else { return }
        isPointerInside = false
        if !isHovered { hoverEnded() }
    }

    /// The island gained keyboard focus.
    public func focusGained() {
        guard !isFocused else { return }
        let wasHovered = isHovered
        isFocused = true
        if !wasHovered { hoverBegan() }
    }

    /// The island lost keyboard focus.
    public func focusLost() {
        guard isFocused else { return }
        isFocused = false
        if !isHovered { hoverEnded() }
    }

    /// The island was clicked: open it now.
    public func click() {
        cancelIslandDelays()
        endHUD()
        level = .open
    }

    /// The collapse button was pressed: return to compact now.
    public func collapse() {
        cancelIslandDelays()
        endHUD()
        level = .compact
    }

    /// Shows `mode` compact, cancelling every pending delay.
    public func selectMode(_ mode: IslandMode) {
        cancelIslandDelays()
        endHUD()
        self.mode = mode
        alert = nil
        level = .compact
    }

    /// Shows `alert`, open when ``IslandSettings/alertExpand`` is on.
    public func alertArrived(_ alert: IslandAlert) {
        cancelIslandDelays()
        endHUD()
        mode = alert.mode
        self.alert = alert
        guard settings.alertExpand else {
            level = .compact
            return
        }
        level = .open
        alertDelay = scheduler.schedule(after: .seconds(settings.alertCollapseSeconds)) {
            [weak self] in
            self?.alertDelayEnded()
        }
    }

    /// A volume, brightness or keyboard brightness key was pressed.
    ///
    /// Ignored when ``IslandSettings/replaceSystemHUDs`` is off.
    public func hudKeyPressed(_ kind: SystemHUDKind) {
        guard settings.replaceSystemHUDs else { return }
        hud = kind
        hudDelay?.cancel()
        hudDelay = scheduler.schedule(after: Self.hudDuration) { [weak self] in
            self?.hudDelayEnded()
        }
    }

    // MARK: Rules

    private func hoverBegan() {
        leaveDelay?.cancel()
        leaveDelay = nil
        guard settings.hoverAction != .off, level == .compact else { return }
        hoverDelay?.cancel()
        hoverDelay = scheduler.schedule(after: .milliseconds(settings.hoverDelayMilliseconds)) {
            [weak self] in
            self?.hoverDelayEnded()
        }
    }

    private func hoverEnded() {
        hoverDelay?.cancel()
        hoverDelay = nil
        guard let milliseconds = leaveDelayMilliseconds() else { return }
        leaveDelay?.cancel()
        leaveDelay = scheduler.schedule(after: .milliseconds(milliseconds)) { [weak self] in
            self?.leaveDelayEnded()
        }
    }

    /// How long after hover ends the island collapses, or `nil` when it stays.
    private func leaveDelayMilliseconds() -> Int? {
        switch level {
        case .compact:
            nil
        case .peek:
            settings.leaveDelayMilliseconds
        case .open:
            if settings.hoverAction == .open {
                settings.leaveDelayMilliseconds
            } else if settings.collapseOnLeave || alert != nil {
                settings.collapseDelayMilliseconds
            } else {
                nil
            }
        }
    }

    private func hoverDelayEnded() {
        hoverDelay = nil
        guard isHovered, level == .compact else { return }
        switch settings.hoverAction {
        case .off: break
        case .peek: level = .peek
        case .open: level = .open
        }
    }

    private func leaveDelayEnded() {
        leaveDelay = nil
        if !isHovered { level = .compact }
    }

    private func alertDelayEnded() {
        alertDelay = nil
        if level == .open, !isHovered { level = .compact }
    }

    private func hudDelayEnded() {
        hudDelay = nil
        hud = nil
    }

    private func cancelIslandDelays() {
        hoverDelay?.cancel()
        leaveDelay?.cancel()
        alertDelay?.cancel()
        hoverDelay = nil
        leaveDelay = nil
        alertDelay = nil
    }

    private func endHUD() {
        hudDelay?.cancel()
        hudDelay = nil
        if hud != nil { hud = nil }
    }
}
