import Foundation

enum QMarkTerminationSource {
    case userInitiated
    case systemInitiated
}

enum QMarkWindowRestorationPolicy {
    private static let nativeSceneRestorationEnabledKey = "QMarkNativeSceneRestorationEnabledForNextLaunch"
    private static let applePersistenceIgnoreStateKey = "ApplePersistenceIgnoreState"

    static func shouldKeepDocumentWindowsRestorable(for source: QMarkTerminationSource) -> Bool {
        switch source {
        case .userInitiated:
            return false
        case .systemInitiated:
            return true
        }
    }

    static func shouldEnableNativeSceneRestorationOnLaunch(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: nativeSceneRestorationEnabledKey)
    }

    static func shouldIgnoreApplePersistenceStateOnLaunch(defaults: UserDefaults = .standard) -> Bool {
        !shouldEnableNativeSceneRestorationOnLaunch(defaults: defaults)
    }

    static func setNativeSceneRestorationEnabledForNextLaunch(
        _ enabled: Bool,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(enabled, forKey: nativeSceneRestorationEnabledKey)
        defaults.synchronize()
    }

    static func setApplePersistenceStateIgnored(_ ignored: Bool, defaults: UserDefaults = .standard) {
        defaults.set(ignored, forKey: applePersistenceIgnoreStateKey)
        defaults.synchronize()
    }
}
