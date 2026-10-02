// HUD spike (#26): Debug builds only.
#if DEBUG

    import Foundation
    import ObjectiveC

    /// The built-in keyboard backlight, through CoreBrightness' private
    /// `KeyboardBrightnessClient` class.
    ///
    /// The class is loaded at run time and its methods are called through their
    /// implementations, cast to C function types that match their type encodings
    /// (`f24@0:8Q16` for `brightnessForKeyboard:`, `B28@0:8f16Q20` for
    /// `setBrightness:forKeyboard:`). No change notification is used: the class has a
    /// `registerNotificationForKeys:keyboardID:block:` method, but its keys are undocumented,
    /// so the spike polls every 0.5 s instead.
    @MainActor
    final class KeyboardBacklight {
        private typealias GetLevel = @convention(c) (AnyObject, Selector, UInt64) -> Float
        private typealias SetLevel = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool
        private typealias GetFlag = @convention(c) (AnyObject, Selector, UInt64) -> Bool

        private static let getSelector = NSSelectorFromString("brightnessForKeyboard:")
        private static let setSelector = NSSelectorFromString("setBrightness:forKeyboard:")
        private static let autoSelector = NSSelectorFromString(
            "isAutoBrightnessEnabledForKeyboard:")
        private static let idsSelector = NSSelectorFromString("copyKeyboardBacklightIDs")

        /// Called on the main thread when the level changed.
        var onChange: (_ level: Double) -> Void = { _ in }

        private let client: NSObject?
        private let keyboardID: UInt64
        private var lastValue: Double?
        private var pollTask: Task<Void, Never>?

        init() {
            let loaded =
                Bundle(path: "/System/Library/PrivateFrameworks/CoreBrightness.framework")?.load()
                ?? false
            let type = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type
            client = type?.init()
            // The built-in keyboard's ID comes from `copyKeyboardBacklightIDs`. On the M5 MacBook
            // Air it is 95158272, but 1 also works, which is what boring.notch hard-codes.
            // Check the selector first: `perform` on a selector the class dropped would crash.
            var ids: [NSNumber] = []
            if let client, client.responds(to: Self.idsSelector) {
                ids = (client.perform(Self.idsSelector)?.takeRetainedValue() as? [NSNumber]) ?? []
            }
            keyboardID = ids.first?.uint64Value ?? 1
            hudSpikeLog.notice(
                "keyboard: CoreBrightness loaded \(loaded) client \(self.client != nil) ids \(ids.map(\.uint64Value), privacy: .public)"
            )
        }

        /// The backlight level from 0 to 1, or `nil` without a client.
        var level: Double? {
            guard let client, let get = implementation(Self.getSelector, as: GetLevel.self) else {
                return nil
            }
            let value = get(client, Self.getSelector, keyboardID)
            return value < 0 ? nil : Double(value)
        }

        var isAutoBrightnessEnabled: Bool? {
            guard let client, let get = implementation(Self.autoSelector, as: GetFlag.self) else {
                return nil
            }
            return get(client, Self.autoSelector, keyboardID)
        }

        func setLevel(_ value: Double) {
            guard let client, let set = implementation(Self.setSelector, as: SetLevel.self) else {
                return
            }
            let ok = set(client, Self.setSelector, Float(min(max(value, 0), 1)), keyboardID)
            hudSpikeLog.notice("keyboard: set \(value) ok \(ok)")
        }

        func start() {
            lastValue = level
            hudSpikeLog.notice(
                "keyboard: id \(self.keyboardID) initial \(self.lastValue ?? -1) auto \(String(describing: self.isAutoBrightnessEnabled), privacy: .public)"
            )
            pollTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(500))
                    self?.check()
                }
            }
        }

        func check() {
            guard let value = level, value != lastValue else { return }
            lastValue = value
            onChange(value)
        }

        private func implementation<T>(_ selector: Selector, as type: T.Type) -> T? {
            guard let client,
                let method = class_getInstanceMethod(object_getClass(client), selector)
            else { return nil }
            return unsafeBitCast(method_getImplementation(method), to: type)
        }
    }

#endif
