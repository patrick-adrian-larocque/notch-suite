import Testing

@testable import NotchCore

@Suite struct AppIdentityTests {
    private let music = "com.apple.Music"
    private let spotify = "com.spotify.client"

    @Test func unknownHasNeitherPart() {
        #expect(AppIdentity.unknown.isUnknown)
        #expect(!AppIdentity(processIdentifier: 1).isUnknown)
        #expect(!AppIdentity(bundleIdentifier: music).isUnknown)
    }

    @Test func matchingPartsAreTheSameApplication() {
        let full = AppIdentity(bundleIdentifier: music, processIdentifier: 812)
        #expect(full.isSameApplication(as: full) == true)
        #expect(full.isSameApplication(as: AppIdentity(processIdentifier: 812)) == true)
        #expect(full.isSameApplication(as: AppIdentity(bundleIdentifier: music)) == true)
    }

    @Test func anyDisagreeingPartIsADifferentApplication() {
        let full = AppIdentity(bundleIdentifier: music, processIdentifier: 812)
        #expect(full.isSameApplication(as: AppIdentity(processIdentifier: 940)) == false)
        #expect(full.isSameApplication(as: AppIdentity(bundleIdentifier: spotify)) == false)
        // Reused process identifier.
        #expect(
            full.isSameApplication(
                as: AppIdentity(bundleIdentifier: spotify, processIdentifier: 812))
                == false)
        // Same app relaunched.
        #expect(
            full.isSameApplication(as: AppIdentity(bundleIdentifier: music, processIdentifier: 940))
                == false)
    }

    /// `nil == nil` must not count as proof of the same application.
    @Test func noSharedPartIsUndecided() {
        #expect(AppIdentity.unknown.isSameApplication(as: .unknown) == nil)
        #expect(AppIdentity(processIdentifier: 812).isSameApplication(as: .unknown) == nil)
        #expect(
            AppIdentity(processIdentifier: 812).isSameApplication(
                as: AppIdentity(bundleIdentifier: music)) == nil)
    }
}
