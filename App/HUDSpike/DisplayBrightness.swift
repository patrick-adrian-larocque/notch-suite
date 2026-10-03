// HUD spike (#26): Debug builds only.
#if DEBUG

    import AppKit

    /// The built-in display's brightness, through the private DisplayServices framework.
    ///
    /// There is no public API for the built-in display's brightness on Apple Silicon: IOKit's
    /// `IODisplayGetFloatParameter` only finds Intel-era `IODisplayConnect` services. So this
    /// loads `DisplayServices` with `dlopen` and looks its functions up with `dlsym`; when a
    /// symbol is missing, the feature is simply off. Changes are observed two ways, so the spike
    /// can tell which one works: DisplayServices' change notification, and a 0.5 s poll.
    @MainActor
    final class DisplayBrightness {
        private typealias GetBrightness =
            @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
        private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32
        private typealias RegisterForChanges =
            @convention(c) (CGDirectDisplayID, UnsafeRawPointer?, CFNotificationCallback) -> Int32

        /// Called on the main thread when the brightness changed, with what noticed it.
        var onChange: (_ brightness: Double, _ source: String) -> Void = { _, _ in }

        let displayID: CGDirectDisplayID
        private let getBrightness: GetBrightness?
        private let setBrightness: SetBrightness?
        private let registerForChanges: RegisterForChanges?
        private var lastValue: Double?
        private var pollTask: Task<Void, Never>?

        /// The instance the C notification callback reports to.
        private static weak var observing: DisplayBrightness?

        init() {
            let builtIn = NSScreen.screens.lazy.compactMap { screen -> CGDirectDisplayID? in
                let key = NSDeviceDescriptionKey("NSScreenNumber")
                guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
                let id = CGDirectDisplayID(number.uint32Value)
                return CGDisplayIsBuiltin(id) != 0 ? id : nil
            }.first
            displayID = builtIn ?? CGMainDisplayID()

            let handle = dlopen(
                "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
                RTLD_LAZY)
            func symbol<T>(_ name: String, as type: T.Type) -> T? {
                guard let handle, let pointer = dlsym(handle, name) else { return nil }
                return unsafeBitCast(pointer, to: type)
            }
            getBrightness = symbol("DisplayServicesGetBrightness", as: GetBrightness.self)
            setBrightness = symbol("DisplayServicesSetBrightness", as: SetBrightness.self)
            registerForChanges = symbol(
                "DisplayServicesRegisterForBrightnessChangeNotifications",
                as: RegisterForChanges.self)
            hudSpikeLog.notice(
                "brightness: display \(self.displayID) builtIn \(builtIn != nil) dlopen \(handle != nil) get \(self.getBrightness != nil) set \(self.setBrightness != nil) register \(self.registerForChanges != nil)"
            )
        }

        /// The brightness from 0 to 1, or `nil` when DisplayServices can't read it.
        var brightness: Double? {
            guard let getBrightness else { return nil }
            var value: Float = 0
            guard getBrightness(displayID, &value) == 0 else { return nil }
            return Double(value)
        }

        /// Returns whether DisplayServices accepted the new brightness.
        func setBrightness(_ value: Double) -> Bool {
            let status = setBrightness?(displayID, Float(min(max(value, 0), 1)))
            hudSpikeLog.notice("brightness: set \(value) status \(String(describing: status))")
            return status == 0
        }

        func start() {
            lastValue = brightness
            hudSpikeLog.notice("brightness: initial \(self.lastValue ?? -1)")
            Self.observing = self
            if let registerForChanges {
                let status = registerForChanges(displayID, nil, brightnessChangeCallback)
                hudSpikeLog.notice("brightness: register for change notifications status \(status)")
            }
            pollTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(500))
                    self?.check(source: "poll")
                }
            }
        }

        /// Reads the brightness and reports it when it moved since the last read.
        func check(source: String) {
            guard let value = brightness, value != lastValue else { return }
            lastValue = value
            onChange(value, source)
        }

        fileprivate static func notificationArrived(_ info: String) {
            hudSpikeLog.notice("brightness: change notification \(info, privacy: .public)")
            observing?.check(source: "notification")
        }
    }

    /// DisplayServices calls this on a thread of its choosing; hop to the main actor.
    private func brightnessChangeCallback(
        center: CFNotificationCenter?, observer: UnsafeMutableRawPointer?,
        name: CFNotificationName?,
        object: UnsafeRawPointer?, userInfo: CFDictionary?
    ) {
        let info = "\(String(describing: name?.rawValue)) \(String(describing: userInfo))"
        Task { @MainActor in DisplayBrightness.notificationArrived(info) }
    }

#endif
