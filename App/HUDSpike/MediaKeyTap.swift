// HUD spike (#26): Debug builds only.
#if DEBUG

    import AppKit
    import NotchCore
    import os

    /// Logs for the HUD spike (#26). Read them with
    /// `log stream --level info --predicate 'subsystem == "com.patricklarocque.NotchSuite"'`.
    let hudSpikeLog = Logger(subsystem: "com.patricklarocque.NotchSuite", category: "HUDSpike")

    /// A volume, brightness or keyboard backlight key, as the `NX_KEYTYPE_*` constants in
    /// IOKit's `ev_keymap.h` number them.
    enum MediaKey: Int, CustomStringConvertible {
        case soundUp = 0
        case soundDown = 1
        case brightnessUp = 2
        case brightnessDown = 3
        case mute = 7
        case illuminationUp = 21
        case illuminationDown = 22
        case illuminationToggle = 23

        var hudKind: SystemHUDKind {
            switch self {
            case .soundUp, .soundDown, .mute: .volume
            case .brightnessUp, .brightnessDown: .brightness
            case .illuminationUp, .illuminationDown, .illuminationToggle: .keyboardBrightness
            }
        }

        var description: String {
            switch self {
            case .soundUp: "soundUp"
            case .soundDown: "soundDown"
            case .brightnessUp: "brightnessUp"
            case .brightnessDown: "brightnessDown"
            case .mute: "mute"
            case .illuminationUp: "illuminationUp"
            case .illuminationDown: "illuminationDown"
            case .illuminationToggle: "illuminationToggle"
            }
        }
    }

    /// One media key transition, decoded from an `NX_SYSDEFINED` event.
    struct MediaKeyEvent: CustomStringConvertible {
        /// `NX_SYSDEFINED`, which `CGEventType` has no case for.
        static let systemDefinedType: UInt32 = 14
        /// `NX_SUBTYPE_AUX_CONTROL_BUTTONS`: the subtype the media keys arrive with.
        static let auxControlButtonsSubtype: Int16 = 8

        var key: MediaKey
        var isKeyDown: Bool
        var isRepeat: Bool
        /// Option and Shift held: the system's quarter-step modifier.
        var isFineStep: Bool

        /// Decodes `event`, or returns `nil` for any other system-defined event.
        ///
        /// `data1` packs the key type into its high 16 bits, the key state into bits 8 to 15
        /// (`0xA` down, `0xB` up) and the repeat flag into bit 0.
        init?(_ event: NSEvent) {
            guard event.type == .systemDefined,
                event.subtype.rawValue == Self.auxControlButtonsSubtype
            else { return nil }
            let data1 = event.data1
            guard let key = MediaKey(rawValue: (data1 & 0xFFFF_0000) >> 16) else { return nil }
            self.key = key
            isKeyDown = (data1 & 0xFF00) >> 8 == 0x0A
            isRepeat = data1 & 0x1 == 0x1
            isFineStep = event.modifierFlags.isSuperset(of: [.option, .shift])
        }

        var description: String {
            "\(key) \(isKeyDown ? "down" : "up")\(isRepeat ? " repeat" : "")"
                + (isFineStep ? " fine" : "")
        }
    }

    /// Watches the media keys with a `CGEventTap` on `NX_SYSDEFINED` events.
    ///
    /// A listen-only tap only sees the keys, and the system still changes the level and shows
    /// its own popup. An active tap can consume them, which stops the system from acting on
    /// them, so the app has to change the level itself. The tap runs on the main run loop.
    @MainActor
    final class MediaKeyTap {
        enum Mode: String {
            /// `.listenOnly` at the session tap. On macOS 27.2 it is created without Input
            /// Monitoring; whether it then receives the keys is still to be checked.
            case listenOnly
            /// `.defaultTap` at the HID tap, consuming handled keys. Without Accessibility,
            /// `tapCreate` returns `nil` and macOS shows its Accessibility prompt itself.
            case suppress
        }

        /// The running tap's mode, or `nil` when no tap is running.
        private(set) var mode: Mode?

        /// Called for every decoded key event. In ``Mode/suppress`` a `true` result consumes
        /// the event; in ``Mode/listenOnly`` the result is ignored.
        var onEvent: (MediaKeyEvent) -> Bool = { _ in false }

        private var tap: CFMachPort?
        private var source: CFRunLoopSource?

        /// Starts a tap in `mode`, replacing any running one. Returns whether it started;
        /// `CGEvent.tapCreate` returns `nil` when the app lacks the permission it needs.
        @discardableResult
        func start(_ mode: Mode) -> Bool {
            stop()
            guard let tap = Self.makeTap(mode, refcon: Unmanaged.passUnretained(self).toOpaque())
            else {
                hudSpikeLog.notice("tap \(mode.rawValue, privacy: .public): tapCreate returned nil")
                return false
            }
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            self.tap = tap
            self.source = source
            self.mode = mode
            hudSpikeLog.notice("tap \(mode.rawValue, privacy: .public): started")
            return true
        }

        func stop() {
            if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
            if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
            if let tap { CFMachPortInvalidate(tap) }
            tap = nil
            source = nil
            mode = nil
        }

        private static func makeTap(_ mode: Mode, refcon: UnsafeMutableRawPointer?) -> CFMachPort? {
            CGEvent.tapCreate(
                tap: mode == .suppress ? .cghidEventTap : .cgSessionEventTap,
                place: .headInsertEventTap,
                options: mode == .suppress ? .defaultTap : .listenOnly,
                eventsOfInterest: CGEventMask(1) << MediaKeyEvent.systemDefinedType,
                callback: mediaKeyTapCallback,
                userInfo: refcon)
        }

        /// Returns whether to consume `event`.
        fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                // The system turns a tap off when its callback is too slow, or when the user
                // enters a secure text field. Turn it back on.
                hudSpikeLog.notice("tap disabled (type \(type.rawValue)), re-enabling")
                if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return false
            }
            guard let nsEvent = NSEvent(cgEvent: event), let key = MediaKeyEvent(nsEvent) else {
                return false
            }
            hudSpikeLog.notice(
                "tap \(self.mode?.rawValue ?? "-", privacy: .public): \(key, privacy: .public)")
            let consume = onEvent(key)
            return mode == .suppress && consume
        }
    }

    /// The C callback for ``MediaKeyTap``. The tap's run loop source is on the main run loop,
    /// so this always runs on the main thread.
    private func mediaKeyTapCallback(
        proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
    ) -> Unmanaged<CGEvent>? {
        guard let refcon else { return Unmanaged.passUnretained(event) }
        // Already on the main thread, so nothing is actually sent anywhere.
        nonisolated(unsafe) let tapPointer = refcon
        nonisolated(unsafe) let tapEvent = event
        let consume = MainActor.assumeIsolated {
            Unmanaged<MediaKeyTap>.fromOpaque(tapPointer).takeUnretainedValue()
                .handle(type: type, event: tapEvent)
        }
        return consume ? nil : Unmanaged.passUnretained(event)
    }

#endif
