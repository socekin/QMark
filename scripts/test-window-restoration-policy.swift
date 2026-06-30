import Foundation

@main
struct WindowRestorationPolicyTest {
    static func main() {
        let suiteName = "com.qmark.tests.window-restoration-policy.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fail("Could not create isolated test defaults")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        expect(
            QMarkWindowRestorationPolicy.shouldKeepDocumentWindowsRestorable(for: .userInitiated) == false,
            "User-initiated close or quit should not preserve restorable document windows"
        )
        expect(
            QMarkWindowRestorationPolicy.shouldKeepDocumentWindowsRestorable(for: .systemInitiated) == true,
            "System-initiated termination should preserve restorable document windows"
        )

        expect(
            QMarkWindowRestorationPolicy.shouldEnableNativeSceneRestorationOnLaunch(defaults: defaults) == false,
            "Native scene restoration should be disabled by default"
        )

        QMarkWindowRestorationPolicy.setNativeSceneRestorationEnabledForNextLaunch(true, defaults: defaults)
        expect(
            QMarkWindowRestorationPolicy.shouldEnableNativeSceneRestorationOnLaunch(defaults: defaults) == true,
            "System termination should be able to enable native scene restoration for the next launch"
        )

        QMarkWindowRestorationPolicy.setNativeSceneRestorationEnabledForNextLaunch(false, defaults: defaults)
        expect(
            QMarkWindowRestorationPolicy.shouldEnableNativeSceneRestorationOnLaunch(defaults: defaults) == false,
            "Normal termination should disable native scene restoration for the next launch"
        )

        expect(
            QMarkWindowRestorationPolicy.shouldIgnoreApplePersistenceStateOnLaunch(defaults: defaults) == true,
            "Apple persistence state should be ignored when native scene restoration is disabled"
        )

        QMarkWindowRestorationPolicy.setNativeSceneRestorationEnabledForNextLaunch(true, defaults: defaults)
        expect(
            QMarkWindowRestorationPolicy.shouldIgnoreApplePersistenceStateOnLaunch(defaults: defaults) == false,
            "Apple persistence state should be allowed after system termination enables restoration"
        )
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
}
