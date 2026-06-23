import Foundation

final class SharedDefaults {
    static let shared = SharedDefaults()

    private let defaults: UserDefaults

    private init() {
        defaults = UserDefaults(suiteName: ModelContainerFactory.appGroupIdentifier)
            ?? UserDefaults.standard
    }

    // MARK: - Quiet Hours

    var quietHoursEnabled: Bool {
        get { defaults.bool(forKey: "quietHoursEnabled") }
        set { defaults.set(newValue, forKey: "quietHoursEnabled") }
    }

    // Stored as seconds since midnight
    var quietHoursStartMinutes: Int {
        get { defaults.object(forKey: "quietHoursStartMinutes") as? Int ?? 22 * 60 }
        set { defaults.set(newValue, forKey: "quietHoursStartMinutes") }
    }

    var quietHoursEndMinutes: Int {
        get { defaults.object(forKey: "quietHoursEndMinutes") as? Int ?? 7 * 60 }
        set { defaults.set(newValue, forKey: "quietHoursEndMinutes") }
    }

    // MARK: - Streak

    var streakCache: Int {
        get { defaults.integer(forKey: "streakCache") }
        set { defaults.set(newValue, forKey: "streakCache") }
    }

    // MARK: - Onboarding

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: "hasCompletedOnboarding") }
        set { defaults.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    // MARK: - Rex Pro (in-app purchase)

    // Cached entitlement so any process (notifications, background tasks) can gate Pro
    // features without touching StoreKit. StoreManager is the source of truth and keeps
    // this in sync; StoreKit's own entitlements are authoritative on the next launch.
    var proUnlocked: Bool {
        get { defaults.bool(forKey: "proUnlocked") }
        set { defaults.set(newValue, forKey: "proUnlocked") }
    }

    // MARK: - iCloud Sync

    // Off by default — requires the iCloud/CloudKit entitlement to be configured first.
    var iCloudSyncEnabled: Bool {
        get { defaults.bool(forKey: "iCloudSyncEnabled") }
        set { defaults.set(newValue, forKey: "iCloudSyncEnabled") }
    }

    // Whether the user has connected Apple Health (tapped through the permission sheet).
    var healthConnected: Bool {
        get { defaults.bool(forKey: "healthConnected") }
        set { defaults.set(newValue, forKey: "healthConnected") }
    }

    // MARK: - Control Center → in-app confirmation

    // Set by the "Next Dose" control (which opens the app); the app reads it on
    // becoming active and presents a "Mark as taken?" confirmation, then clears it.
    // Encoded as "prescriptionId|scheduledDateInterval|name".
    var pendingDoseConfirmation: String? {
        get { defaults.string(forKey: "pendingDoseConfirmation") }
        set { defaults.set(newValue, forKey: "pendingDoseConfirmation") }
    }
}
