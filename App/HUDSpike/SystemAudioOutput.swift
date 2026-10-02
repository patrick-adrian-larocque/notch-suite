// HUD spike (#26): Debug builds only.
#if DEBUG

    import AudioToolbox
    import CoreAudio
    import Foundation

    /// The default output device's volume and mute, read, written and observed with CoreAudio.
    ///
    /// Volume uses `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`, the single value
    /// the menu bar slider shows, and falls back to the main element's
    /// `kAudioDevicePropertyVolumeScalar`. Listeners move to the new device when the default
    /// output changes.
    @MainActor
    final class SystemAudioOutput {
        /// Called on the main thread after volume or mute changed, with which listener fired.
        var onChange: (_ volume: Double, _ isMuted: Bool, _ source: String) -> Void = { _, _, _ in }

        private(set) var deviceID = AudioObjectID(kAudioObjectUnknown)
        private var deviceListeners:
            [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] =
                []
        private var defaultDeviceListener: AudioObjectPropertyListenerBlock?

        private static let virtualMainVolume = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        private static let scalarVolume = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        private static let mute = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        private static let defaultOutput = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        func start() {
            var address = Self.defaultOutput
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                MainActor.assumeIsolated { self?.attachToDefaultDevice() }
            }
            let status = AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, block)
            defaultDeviceListener = block
            hudSpikeLog.notice("audio: default-device listener status \(status)")
            attachToDefaultDevice()
        }

        /// The volume from 0 to 1, or `nil` when the device has no volume control.
        var volume: Double? {
            if let value: Float32 = read(Self.virtualMainVolume) { return Double(value) }
            if let value: Float32 = read(Self.scalarVolume) { return Double(value) }
            return nil
        }

        var isMuted: Bool? {
            (read(Self.mute) as UInt32?).map { $0 != 0 }
        }

        /// Returns whether the device took the new volume.
        func setVolume(_ volume: Double) -> Bool {
            let value = Float32(min(max(volume, 0), 1))
            return write(Self.virtualMainVolume, value) || write(Self.scalarVolume, value)
        }

        /// Returns whether the device took the new mute state.
        func setMuted(_ muted: Bool) -> Bool {
            write(Self.mute, UInt32(muted ? 1 : 0))
        }

        private func attachToDefaultDevice() {
            for (address, block) in deviceListeners {
                var address = address
                AudioObjectRemovePropertyListenerBlock(
                    deviceID, &address, DispatchQueue.main, block)
            }
            deviceListeners = []

            var device = AudioObjectID(kAudioObjectUnknown)
            var size = UInt32(MemoryLayout<AudioObjectID>.size)
            var address = Self.defaultOutput
            let status = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
            deviceID = status == noErr ? device : AudioObjectID(kAudioObjectUnknown)

            for (name, property) in [
                ("virtualMainVolume", Self.virtualMainVolume), ("volumeScalar", Self.scalarVolume),
                ("mute", Self.mute),
            ] {
                var property = property
                guard AudioObjectHasProperty(deviceID, &property) else {
                    hudSpikeLog.notice(
                        "audio: device \(self.deviceID) has no \(name, privacy: .public)")
                    continue
                }
                let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                    MainActor.assumeIsolated { self?.changed(source: name) }
                }
                let added = AudioObjectAddPropertyListenerBlock(
                    deviceID, &property, DispatchQueue.main, block)
                if added == noErr { deviceListeners.append((property, block)) }
                var settable = DarwinBoolean(false)
                AudioObjectIsPropertySettable(deviceID, &property, &settable)
                hudSpikeLog.notice(
                    "audio: device \(self.deviceID) \(name, privacy: .public) listener \(added), settable \(settable.boolValue)"
                )
            }
            hudSpikeLog.notice(
                "audio: device \(self.deviceID) volume \(self.volume ?? -1) muted \(String(describing: self.isMuted), privacy: .public)"
            )
        }

        private func changed(source: String) {
            guard let volume else { return }
            onChange(volume, isMuted ?? false, source)
        }

        private func read<Value: BitwiseCopyable>(_ address: AudioObjectPropertyAddress) -> Value? {
            var address = address
            guard deviceID != kAudioObjectUnknown, AudioObjectHasProperty(deviceID, &address) else {
                return nil
            }
            var size = UInt32(MemoryLayout<Value>.size)
            let pointer = UnsafeMutablePointer<Value>.allocate(capacity: 1)
            defer { pointer.deallocate() }
            guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, pointer) == noErr
            else { return nil }
            return pointer.pointee
        }

        private func write<Value: BitwiseCopyable>(
            _ address: AudioObjectPropertyAddress, _ value: Value
        ) -> Bool {
            var address = address
            var value = value
            guard deviceID != kAudioObjectUnknown, AudioObjectHasProperty(deviceID, &address) else {
                return false
            }
            let size = UInt32(MemoryLayout<Value>.size)
            return AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &value) == noErr
        }
    }

#endif
