// HUD spike (#26): Debug builds only.
#if DEBUG

    import AppKit
    import NotchCore
    import SwiftUI

    /// The volume and brightness HUD spike (#26).
    ///
    /// Off unless the `HUDSpike` default is set, and only in Debug builds:
    ///
    ///     open NotchSuite.app --args -HUDSpike YES
    ///
    /// It observes the media keys three ways (a listen-only event tap, an active event tap
    /// when "Suppress system HUD" is on, and an `NSEvent` global monitor, which only logs),
    /// observes the levels (CoreAudio, DisplayServices, CoreBrightness), and shows a prototype
    /// HUD in its own panel at the notch. It adds a status item with the permission state,
    /// the suppress toggle, permission requests and HUD previews. Everything it learns goes to
    /// the `HUDSpike` log category.
    @MainActor
    final class HUDSpikeController: NSObject, NSMenuDelegate {
        static let defaultsKey = "HUDSpike"

        private static var running: HUDSpikeController?

        /// Starts the spike when the `HUDSpike` default is on.
        static func startIfEnabled() {
            guard UserDefaults.standard.bool(forKey: defaultsKey) else { return }
            let controller = HUDSpikeController()
            controller.start()
            running = controller
        }

        /// A brightness or backlight change at least this big shows the HUD without a key
        /// press. Smaller ones are ambient-light adjustments, which shouldn't pop the HUD.
        private static let unpromptedChangeThreshold = 0.03

        private let machine = IslandStateMachine(scheduler: HUDSpikeDelayScheduler())
        private let model: HUDSpikeModel
        private let audio = SystemAudioOutput()
        private let display = DisplayBrightness()
        private let keyboard = KeyboardBacklight()
        private let tap = MediaKeyTap()
        private let provider = ScreenNotchGeometryProvider()
        private let panel = NotchPanel()
        private let menu = NSMenu()
        private var statusItem: NSStatusItem?
        private var globalMonitor: Any?
        private var lastKeyPress: [SystemHUDKind: ContinuousClock.Instant] = [:]
        private var lastBacklightLevel = 0.5
        /// Keys whose key-down suppress mode consumed, so their key-up is consumed too.
        private var consumedKeys: Set<MediaKey> = []
        private var lastAnnouncement = ""

        override init() {
            model = HUDSpikeModel(machine: machine)
            super.init()
        }

        private func start() {
            let os = ProcessInfo.processInfo.operatingSystemVersionString
            hudSpikeLog.notice(
                "start: macOS \(os, privacy: .public), Accessibility \(AXIsProcessTrusted()), Input Monitoring \(CGPreflightListenEventAccess()), post events \(CGPreflightPostEventAccess())"
            )

            audio.onChange = { [weak self] volume, muted, source in
                self?.volumeChanged(volume, muted: muted, source: source)
            }
            audio.start()
            model.volume = audio.volume ?? 0
            model.isMuted = audio.isMuted ?? false

            display.onChange = { [weak self] value, source in
                self?.brightnessChanged(value, source: source)
            }
            display.start()
            model.brightness = display.brightness ?? 0

            keyboard.onChange = { [weak self] value in self?.backlightChanged(value) }
            keyboard.start()
            model.keyboard = keyboard.level ?? 0

            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { event in
                guard let key = MediaKeyEvent(event) else { return }
                hudSpikeLog.notice("global monitor: \(key, privacy: .public)")
            }
            hudSpikeLog.notice("global monitor installed \(self.globalMonitor != nil)")

            // No active tap here: creating one without Accessibility pops the system prompt,
            // so that waits for the "Suppress System HUD" menu item.
            tap.onEvent = { [weak self] event in self?.keyEvent(event) ?? false }
            tap.start(.listenOnly)

            setUpPanel()
            setUpStatusItem()
            hudSpikeLog.notice("start: observers started")
        }

        // MARK: Keys

        /// Returns whether to consume the event, which only matters in suppress mode.
        private func keyEvent(_ event: MediaKeyEvent) -> Bool {
            let kind = event.key.hudKind
            guard tap.mode == .suppress else {
                // The system applies the change after this event, so read the level again
                // shortly. CoreAudio reports volume itself; brightness would wait for the poll.
                if event.isKeyDown {
                    lastKeyPress[kind] = .now
                    // The level hasn't changed yet; the level observers announce it.
                    show(kind, announce: false)
                    Task { [weak self] in
                        try? await Task.sleep(for: .milliseconds(80))
                        self?.display.check(source: "key+80ms")
                        self?.keyboard.check()
                    }
                }
                return false
            }
            // A key-up is consumed only when its key-down was, so the system never sees
            // half a press.
            guard event.isKeyDown else { return consumedKeys.remove(event.key) != nil }
            lastKeyPress[kind] = .now
            // When the backend is missing or the write fails, let macOS handle the key.
            guard apply(event) else {
                hudSpikeLog.notice("suppress: \(event, privacy: .public) not handled, passed on")
                consumedKeys.remove(event.key)
                return false
            }
            consumedKeys.insert(event.key)
            // The level observers announce the new value once it has landed.
            show(kind, announce: false)
            return true
        }

        /// Changes the level the way the system would, in 1/16 steps, or 1/64 with
        /// Option-Shift. Returns whether the level could be read and written.
        private func apply(_ event: MediaKeyEvent) -> Bool {
            let step = event.isFineStep ? 1.0 / 64 : 1.0 / 16
            func stepped(_ value: Double, _ direction: Double) -> Double {
                min(max(((value / step).rounded() + direction) * step, 0), 1)
            }
            switch event.key {
            case .soundUp, .soundDown:
                guard let volume = audio.volume else { return false }
                if event.key == .soundUp, audio.isMuted == true { _ = audio.setMuted(false) }
                return audio.setVolume(stepped(volume, event.key == .soundUp ? 1 : -1))
            case .mute:
                guard let muted = audio.isMuted else { return false }
                return audio.setMuted(!muted)
            case .brightnessUp, .brightnessDown:
                guard let brightness = display.brightness else { return false }
                let direction = event.key == .brightnessUp ? 1.0 : -1.0
                guard display.setBrightness(stepped(brightness, direction)) else { return false }
                display.check(source: "key")
                return true
            case .illuminationUp, .illuminationDown:
                guard let level = keyboard.level else { return false }
                let direction = event.key == .illuminationUp ? 1.0 : -1.0
                guard keyboard.setLevel(stepped(level, direction)) else { return false }
                keyboard.check()
                return true
            case .illuminationToggle:
                guard let level = keyboard.level else { return false }
                if level > 0 { lastBacklightLevel = level }
                guard keyboard.setLevel(level > 0 ? 0 : lastBacklightLevel) else { return false }
                keyboard.check()
                return true
            }
        }

        // MARK: Levels

        private func volumeChanged(_ volume: Double, muted: Bool, source: String) {
            hudSpikeLog.notice(
                "level: volume \(volume) muted \(muted) via \(source, privacy: .public)")
            model.volume = volume
            model.isMuted = muted
            show(.volume)
        }

        private func brightnessChanged(_ value: Double, source: String) {
            let delta = value - model.brightness
            hudSpikeLog.notice(
                "level: brightness \(value) (delta \(delta)) via \(source, privacy: .public)")
            model.brightness = value
            if abs(delta) >= Self.unpromptedChangeThreshold || pressedRecently(.brightness) {
                show(.brightness)
            }
        }

        private func backlightChanged(_ value: Double) {
            let delta = value - model.keyboard
            hudSpikeLog.notice("level: keyboard \(value) (delta \(delta))")
            model.keyboard = value
            if abs(delta) >= Self.unpromptedChangeThreshold || pressedRecently(.keyboardBrightness)
            {
                show(.keyboardBrightness)
            }
        }

        private func pressedRecently(_ kind: SystemHUDKind) -> Bool {
            guard let last = lastKeyPress[kind] else { return false }
            return last.duration(to: .now) < .seconds(1)
        }

        // MARK: HUD

        /// Shows the HUD. Only callers that already hold the new level announce it, so
        /// VoiceOver never reads a stale value first.
        private func show(_ kind: SystemHUDKind, announce shouldAnnounce: Bool = true) {
            machine.hudKeyPressed(kind)
            panel.orderFrontRegardless()
            if shouldAnnounce {
                announce(HUDSpikeState(kind: kind, model: model).accessibilityLabel)
            }
        }

        /// Stands in for `role="status"`: VoiceOver reads the new level without focus moving.
        private func announce(_ text: String) {
            guard NSWorkspace.shared.isVoiceOverEnabled, text != lastAnnouncement else { return }
            lastAnnouncement = text
            NSAccessibility.post(
                element: NSApp as Any, notification: .announcementRequested,
                userInfo: [
                    .announcement: text,
                    .priority: NSAccessibilityPriorityLevel.medium.rawValue,
                ])
        }

        private func setUpPanel() {
            let hostingView = NSHostingView(rootView: HUDSpikeView(model: model))
            hostingView.sizingOptions = []
            panel.contentView = hostingView
            NotificationCenter.default.addObserver(
                self, selector: #selector(placePanel),
                name: NSApplication.didChangeScreenParametersNotification, object: nil)
            placePanel()
        }

        @objc private func placePanel() {
            guard let screen = provider.screen, let geometry = provider.geometry() else { return }
            let size = HUDSpikeView.size
            panel.setFrame(
                NSRect(
                    x: screen.frame.minX + geometry.islandMinX(forIslandWidth: size.width),
                    y: screen.frame.maxY - size.height,
                    width: size.width, height: size.height),
                display: true)
            panel.orderFrontRegardless()
        }

        // MARK: Status item

        private func setUpStatusItem() {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = NSImage(
                systemSymbolName: "speaker.wave.2.circle", accessibilityDescription: "HUD spike")
            menu.delegate = self
            item.menu = menu
            statusItem = item
        }

        nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
            MainActor.assumeIsolated { rebuildMenu() }
        }

        private func rebuildMenu() {
            menu.removeAllItems()
            func info(_ title: String) {
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
            func action(_ title: String, _ selector: Selector, checked: Bool = false) {
                let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
                item.target = self
                item.state = checked ? .on : .off
                menu.addItem(item)
            }
            info("HUD spike (#26)")
            info("Accessibility: \(AXIsProcessTrusted() ? "granted" : "not granted")")
            info("Input Monitoring: \(CGPreflightListenEventAccess() ? "granted" : "not granted")")
            info("Event tap: \(tap.mode?.rawValue ?? "not running")")
            menu.addItem(.separator())
            action(
                "Suppress System HUD (Active Tap)", #selector(toggleSuppress),
                checked: tap.mode == .suppress)
            action("Retry Listen-Only Tap", #selector(retryListenTap))
            action("Request Accessibility…", #selector(requestAccessibility))
            action("Request Input Monitoring…", #selector(requestInputMonitoring))
            menu.addItem(.separator())
            action("Preview Volume HUD", #selector(previewVolume))
            action("Preview Brightness HUD", #selector(previewBrightness))
            action("Preview Keyboard HUD", #selector(previewKeyboard))
        }

        @objc private func toggleSuppress() {
            if tap.mode == .suppress {
                tap.start(.listenOnly)
            } else if !tap.start(.suppress) {
                hudSpikeLog.notice("suppress: active tap failed; Accessibility is probably missing")
                tap.start(.listenOnly)
            }
        }

        @objc private func retryListenTap() {
            tap.start(.listenOnly)
        }

        @objc private func requestAccessibility() {
            // `kAXTrustedCheckOptionPrompt` is a mutable C global, which Swift 6 rejects.
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            hudSpikeLog.notice("request Accessibility: \(AXIsProcessTrustedWithOptions(options))")
        }

        @objc private func requestInputMonitoring() {
            hudSpikeLog.notice("request Input Monitoring: \(CGRequestListenEventAccess())")
        }

        @objc private func previewVolume() { show(.volume) }
        @objc private func previewBrightness() { show(.brightness) }
        @objc private func previewKeyboard() { show(.keyboardBrightness) }
    }

    /// Runs `IslandStateMachine`'s HUD timer on a main-actor `Task`.
    @MainActor
    private struct HUDSpikeDelayScheduler: DelayScheduler {
        func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void)
            -> any ScheduledDelay
        {
            HUDSpikeDelay(
                task: Task { @MainActor in
                    try? await Task.sleep(for: delay)
                    // Cancellation also happens on the main actor, so this check can't race it.
                    guard !Task.isCancelled else { return }
                    action()
                })
        }
    }

    @MainActor
    private struct HUDSpikeDelay: ScheduledDelay {
        let task: Task<Void, Never>

        func cancel() { task.cancel() }
    }

#endif
