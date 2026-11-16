import XCTest
@testable import BoozeBlocker

final class FeatureFlagsTests: XCTestCase {
    func testAllFlagsDefaultToOff() {
        let name = "FeatureFlagsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        for flag in FeatureFlags.allCases {
            XCTAssertFalse(flag.isEnabled(defaults: defaults), flag.rawValue)
        }
    }

    func testOverridesAreDebugOnly() {
        let name = "FeatureFlagsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        for flag in FeatureFlags.allCases {
            defaults.set(true, forKey: "feature.\(flag.rawValue)")
            #if DEBUG
            XCTAssertTrue(flag.isEnabled(defaults: defaults))
            #else
            XCTAssertFalse(flag.isEnabled(defaults: defaults))
            #endif
            defaults.set(false, forKey: "feature.\(flag.rawValue)")
            XCTAssertFalse(flag.isEnabled(defaults: defaults))
        }
    }
}
